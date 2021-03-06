package WWW::SFDC::Tooling;
# ABSTRACT: Interface to the Salesforce.com Tooling API

use 5.12.0;
use strict;
use warnings;

# VERSION

use Log::Log4perl ':easy';
use Scalar::Util 'blessed';

use Moo;
with 'WWW::SFDC::Role::SessionConsumer', 'WWW::SFDC::Role::CRUD';

has 'uri',
  is => 'ro',
  default => 'urn:tooling.soap.sforce.com';

sub _extractURL {
  return $_[1]->{serverUrl} =~ s{/u/}{/T/}r;
}

sub _prepareSObjects {
  my $self = shift;
  # prepares an array of objects for an update or insert call by converting
  # it to an array of SOAP::Data

  # THIS IMPLEMENTATION IS DIFFERENT TO THE EQUIVALENT PARTNER API IMPLEMENTATION

  TRACE "objects for operation" => \@_;

  return map {
      my $obj = $_;
      my $type;
      if ($obj->{type}) {
        $type = $obj->{type};
        delete $obj->{type};
      }

      SOAP::Data->name(sObjects => \SOAP::Data->value(
        map {
          (blessed ($obj->{$_}) and blessed ($obj->{$_}) eq 'SOAP::Data')
            ? $obj->{$_}
            : SOAP::Data->name($_ => $obj->{$_})
        } keys %$obj
      ))->type($type)
    } @_;
}

=method executeAnonymous

    $client->Tooling->executeAnonymous("system.debug(1);")

=cut

sub executeAnonymous {
  my ($self, $code, %options) = @_;
  my $result = $self->_call(
    'executeAnonymous',
    SOAP::Data->name(string => $code),
    $options{debug} ? SOAP::Header->name('DebuggingHeader' => \SOAP::Data->name(
        debugLevel => 'DEBUGONLY'
      )) : (),
   )->result;

  LOGDIE "ExecuteAnonymous failed to compile: " . $result->{compileProblem}
    if $result->{compiled} eq "false";

  LOGDIE "ExecuteAnonymous failed to complete: " . $result->{exceptionMessage}
    if $result->{success} eq "false";

  return $result;
}

=method runTests

  $client->Tooling->runTests('name','name2');

returns a RunTestResult hash which looks like:

{
  successes => [{
      name => 'MyTest',
      id => '...',
      namespace => undef,
      time => 123, #time in MS
      methodName => 'something'
    },
    ...
  ],
  failures => [{...}]
  totalTime => 1234,
  numFailures => 3,
  numTestsRun => 4,
  codeCoverage => [
    # HUGE LIST OF HUGH HASHREFS GOES HERE.
  ]

}

=cut

sub runTests {
  my ($self, @names) = @_;

  return $self->_call(
    'runTests',
    map {\SOAP::Data->name(classes => $_)} @names
  )->result;
}

=method runTestsAsynchronous

Takes a list of IDs of test classes.
Returns the ID of the enqueued test run.

=cut

sub runTestsAsynchronous {
  my ($self, @ids) = @_;

  return $self->_call('runTestsAsynchronous', join ",", @ids)->result;
}

1;

__END__

=head1 SYNOPSIS

   my $result = WWW::SFDC->new(
    username => $USER,
    password => $PASS,
    url => $URL
   )->Tooling->executeAnonymous("System.debug(1);");

Note that $URL is the _login_ URL, not the Tooling API endpoint URL - which gets calculated internally.

This module consumes L<WWW::SFDC::Role::CRUD>.

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/sophos/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Tooling

You can also look for information at L<https://github.com/sophos/WWW-SFDC>
