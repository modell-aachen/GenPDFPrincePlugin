# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Michael Daum http://michaeldaumconsulting.com
#
# This license applies to GenPDFPrincePlugin *and also to any derivatives*
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::GenPDFPrincePlugin;

use strict;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Error qw(:try);

our $VERSION = '$Rev: 4419 (2009-07-03) $';
our $RELEASE = '1.2';
our $SHORTDESCRIPTION = 'Generate PDF using Prince XML';
our $NO_PREFS_IN_TOPIC = 1;
our $baseTopic;
our $baseWeb;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "GenPDFPrincePlugin - $_[0]\n" if DEBUG;
}

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  if ($Foswiki::Plugins::VERSION < 2.0) {
    Foswiki::Func::writeWarning('Version mismatch between ',
    __PACKAGE__, ' and Plugins.pm');
    return 0;
  }

  return 1;
}

###############################################################################
sub completePageHandler {
  #my($html, $httpHeaders) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param("contenttype") || 'text/html';

  # is this a pdf view?
  return unless $contenttype eq "application/pdf";

  require File::Temp;
  require Foswiki::Sandbox;

  # remove left-overs
  $_[0] =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

  # clean url params in anchors as prince can't generate proper xrefs otherwise;
  # hope this gets fixed in prince at some time
  $_[0] =~ s/(href=["'])\?.*(#[^"'\s])+/$1$2/g;

  # create temp files
  my $htmlFile = new File::Temp(SUFFIX => '.html');
  my $pdfFile = new File::Temp(SUFFIX => '.pdf');
  my $errorFile = new File::Temp(SUFFIX => '.log');

  # creater html file
  print $htmlFile "$_[0]";
  #writeDebug("htmlFile=".$_[0]);

  # create prince command
  my $session = $Foswiki::Plugins::SESSION;
  my $pubUrl = $session->getPubUrl(1);
  my $princeCmd = $Foswiki::cfg{GenPDFPrincePlugin}{PrinceCmd} || 
    '/usr/bin/prince --baseurl %BASEURL|U% -i html -o %OUTFILE|F% %INFILE|F% --log=%ERROR|F%';

  writeDebug("princeCmd=$princeCmd");
  writeDebug("BASEURL=$pubUrl");

  # execute
  my ($output, $exit) = Foswiki::Sandbox->sysCommand(
      $princeCmd, 
      BASEURL => $pubUrl,
      OUTFILE => $pdfFile->filename,
      INFILE => $htmlFile->filename,
      ERROR => $errorFile->filename,
    );

  local $/ = undef;

  my $error = '';
  if ($exit || DEBUG) {
    $error = <$errorFile>;
  }

  writeDebug("GenPDFPrincePlugin - error=$error");
  writeDebug("GenPDFPrincePlugin - output=$output");

  if ($exit) {
    my $html = $_[0];
    my $line = 1;
    $html = '00000: '.$html;
    $html =~ s/\n/"\n".(sprintf "\%05d", $line++).": "/ge;
    throw Error::Simple("execution of prince failed ($exit): \n\n$error\n\n$html");
  }


  $_[0] = <$pdfFile>;
}

###############################################################################
sub modifyHeaderHandler {
  my ($hopts, $request) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param("contenttype") || 'text/html';

  # is this a pdf view?
  return unless $contenttype eq "application/pdf";

  # add disposition
  $hopts->{'Content-Disposition'} = "inline;filename=$baseTopic.pdf";
}

1;
