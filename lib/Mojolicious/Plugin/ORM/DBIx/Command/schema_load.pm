package Mojolicious::Plugin::ORM::DBIx::Command::schema_load;
use v5.26;
use warnings;

=pod

=head1 SYNOPSIS

  Usage: <APP> schema-load [--debug]

  Options:
    --debug            During load, print generated code to STDERR

=cut

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config pass_through);

use experimental qw(signatures builtin);

has description => '*Create/update DBIx classes from database';
has usage       => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  GetOptionsFromArray(\@args,
    debug   => \my $debug,
  );

  $self->app->db->load_schema($debug);
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
