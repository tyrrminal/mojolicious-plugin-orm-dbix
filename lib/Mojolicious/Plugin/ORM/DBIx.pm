package Mojolicious::Plugin::ORM::DBIx;
use v5.26;
use warnings;

# ABSTRACT: provides middleware for conveniently accessing DBIx::Class from Mojo apps

=encoding UTF-8
 
=head1 NAME
 
Data::Transfigure - performs rule-based data transfigurations of arbitrary structures
 
=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 register

=head2 db

=head2 model

=head1 COMMANDS

=head2 schema-tool

=cut

use Mojo::Base 'Mojolicious::Plugin';

use experimental qw(signatures);

# $args is a hashref with (all optional) keys:
#  namespace      - the root namespace for the DBIx model classes. E.g., <App>::Model
#  dsn            - the DBI connection string for the database. Defaults to in-memory SQLite
#  connect_params - a hashref of additional parameters to pass to the database connect call
#  username       - the database username
#  password       - the database password
sub register($self, $app, $conf) {
  push($app->commands->namespaces->@*, 'Mojolicious::Plugin::ORM::DBIx::Command');

  my %params = (
    mojo_log        => $app->log,
    model_directory => $app->home->child('lib')->to_string,

    namespace      => $conf->{namespace} // join(q{::}, ucfirst($app->moniker), 'Model'),
    dsn            => $conf->{dsn} // 'dbi:SQLite:dbname=:memory:',
    username       => $conf->{username},
    password       => $conf->{password},
    connect_params => $conf->{connect_params} // {},

    dbix_components            => $conf->{dbix_components},
    additional_dbix_components => $conf->{'+dbix_components'},
    feature_bundle             => $conf->{feature_bundle},
    tidy_guards                => $conf->{tidy_guards},
  );
  foreach (keys(%params)) {
    delete($params{$_}) unless(defined($params{$_}));
  }

  my $accessor = Mojolicious::Plugin::ORM::DBIx::Accessor->new(%params);

  $app->helper(
    db => sub($c) {
      return $accessor;
    }
  );

  $app->helper(
    model => sub($c, $model) {
      return $c->db->schema->resultset($model);
    }
  )
  
}

package Mojolicious::Plugin::ORM::DBIx::Accessor;
use v5.26;
use warnings;
use Moose;

use DBI;
use DBIx::Class::Schema::Loader qw(make_schema_at);
use Mojo::Util qw(class_to_path);

use experimental qw(signatures);

has mojo_log => (
  is        => 'ro',
  isa       => 'Mojo::Log',
  predicate => 'has_mojo_log'
);

has namespace => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has dsn => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has connect_params => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {} }
);

has schema => (
  is       => 'ro',
  isa      => 'DBIx::Class::Schema',
  init_arg => undef,
  builder  => '_build_schema',
  lazy     => 1,
);

has username => (
  is       => 'ro',
  isa      => 'Str|Undef',
  required => 0,
);

has password => (
  is       => 'ro',
  isa      => 'Str|Undef',
  required => 0,
);

has model_directory => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has tidy_guards => (
  is      => 'ro',
  isa     => 'Undef|ArrayRef[Str]',
  default => sub { ['## use tidy', '## no tidy'] }
);

has feature_bundle => (
  is        => 'ro',
  isa       => 'Str|Undef',
  default   => "$^V"
);

has _parsed_dsn => (
  is       => 'ro',
  isa      => 'HashRef',
  init_arg => undef,
  builder  => '_build_parsed_dsn',
  lazy     => 1,
);

has codegen_filters => (
  is      => 'rw',
  isa     => 'ArrayRef[CodeRef]',
  default => sub { [] }
);

has dbix_components => (
  is      => 'rw',
  isa     => 'ArrayRef[Str]',
  default => sub { [qw(Relationship::Predicate InflateColumn::DateTime)] }
);

has additional_dbix_components => (
  is      => 'rw',
  isa     => 'ArrayRef[Str]',
  default => sub { [] }
);

sub BUILD($self, $args) {
  push($self->dbix_components->@*, $self->additional_dbix_components->@*);
}

sub _build_schema($self) {
  require(class_to_path($self->namespace));
  $self->namespace->connect($self->dsn, $self->credentials, $self->connect_params);
}

sub _build_parsed_dsn($self) {
  my ($scheme, $driver, $attr_string, $attr_hash, $driver_dsn) = DBI->parse_dsn($self->dsn);
  my %driver_param = split(/[;=]/, $driver_dsn);
  {
    scheme => $scheme,
    driver => $driver,
    params => $attr_hash // {},
    %driver_param,
  }
}

sub credentials ($self) {
  return grep {defined} ($self->username, $self->password)
}

sub database ($self) {
  return $self->_parsed_dsn->{database}
}

sub host ($self) {
  return $self->_parsed_dsn->{host}
}

sub port ($self) {
  return $self->_parsed_dsn->{port}
}

sub driver ($self) {
  return $self->_parsed_dsn->{driver}
}

sub load_schema($self, $debug = 0) {
  $self->mojo_log->debug("Creating model from database schema") if($self->has_mojo_log);
  my @filters = $self->codegen_filters->@*;
  if(defined($self->feature_bundle)) {
    unshift(@filters, sub($text) { $text .= sprintf("\nuse %s;", $self->feature_bundle) });
  }
  if(defined($self->tidy_guards)) {
    unshift(@filters, sub($text) { join("\n", $self->tidy_guards->[1], $text, $self->tidy_guards->[0]) })
  }
  make_schema_at(
    $self->namespace,
    {
      debug                   => $debug,
      overwrite_modifications => 1,
      dump_directory          => $self->model_directory,
      components              => $self->dbix_components,
      filter_generated_code   => sub ($type, $class, $text) {
        $text = $_->($text) foreach (@filters);
        return $text;
      }
    },
    [$self->dsn, $self->credentials]
  )
}

=pod

=head1 AUTHOR

Mark Tyrrell C<< <mark@tyrrminal.dev> >>

=head1 LICENSE

Copyright (c) 2024 Mark Tyrrell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut

1;

__END__
