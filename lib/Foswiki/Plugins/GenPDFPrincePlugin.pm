# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2012 Michael Daum http://michaeldaumconsulting.com
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
use File::Path ();
use Encode ();

our $VERSION = '1.32';
our $RELEASE = "1.32";
our $SHORTDESCRIPTION = 'Generate PDF using Prince XML';
our $NO_PREFS_IN_TOPIC = 1;
our $baseTopic;
our $baseWeb;

use constant TRACE => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "GenPDFPrincePlugin - $_[0]\n" if TRACE;
}

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  if ($Foswiki::Plugins::VERSION < 2.0) {
    Foswiki::Func::writeWarning('Version mismatch between ',
    __PACKAGE__, ' and Plugins.pm');
    return 0;
  }

  Foswiki::Func::registerRESTHandler(
    'getFile', \&_restGetFile,
    authenticate => 1,
    http_allow => 'GET',
    validate => 0
  );

  return 1;
}

###############################################################################
sub completePageHandler {
  #my($html, $httpHeaders) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param("contenttype") || 'text/html';

  # is this a pdf view?
  return unless $contenttype eq "application/pdf";

  # don't print login-boxes
  my $wikiName = Foswiki::Func::getWikiName();
  return unless Foswiki::Func::checkAccessPermission( 'VIEW', $wikiName, undef, $baseTopic, $baseWeb ); 

  require File::Temp;
  require Foswiki::Sandbox;

  # remove left-overs
  $_[0] =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

  # clean url params in anchors as prince can't generate proper xrefs otherwise;
  # hope this gets fixed in prince at some time
  $_[0] =~ s/(href=["'])\?.*(#[^"'\s])+/$1$2/g;

  # rewrite some urls to use file://..
  #$_[0] =~ s/(<link[^>]+href=["'])([^"']+)(["'])/$1.toFileUrl($2).$3/ge;
  $_[0] =~ s/(<img[^>]+src=["'])([^"']+)(["'])/$1.toFileUrl($2).$3/ge;

  # create temp files
  my $modactmpDir = Foswiki::Func::getWorkArea( 'GenPDFPrincePlugin' );
  my $htmlFile = new File::Temp(DIR => $modactmpDir, SUFFIX => '.html', UNLINK => (TRACE?0:1));
  my $errorFile = new File::Temp(DIR => $modactmpDir, SUFFIX => '.log', UNLINK => (TRACE?0:1));
  my $modacpdfFile = new File::Temp(DIR => $modactmpDir, TEMPLATE => "${wikiName}XXXXXXXX", SUFFIX => '.pdf', UNLINK => 0);
  die unless $modacpdfFile =~ m#^$modactmpDir/$wikiName(.*)\.pdf$#;
  my $token = $1;

  # creater html file
  my $content = $_[0];
  if ($Foswiki::cfg{Site}{CharSet} !~ /^utf-?8$/i) {
    $content = Encode::encode('UTF-8', Encode::decode($Foswiki::cfg{Site}{CharSet} || 'iso-8859-1', $content));
  }

  if($Foswiki::UNICODE) {
    $content = Foswiki::encode_utf8($content);
  }

  print $htmlFile $content;
  writeDebug("htmlFile=".$htmlFile->filename);

  # create prince command
  my $session = $Foswiki::Plugins::SESSION;
  my $pubUrl = $session->getPubURL(1); # SMELL: unofficial api
  my $princeCmd = $Foswiki::cfg{GenPDFPrincePlugin}{PrinceCmd} || 
    '/usr/bin/prince --baseurl %BASEURL|U% -i html -o %OUTFILE|F% %INFILE|F% --log=%ERROR|F%';

  writeDebug("princeCmd=$princeCmd");
  writeDebug("BASEURL=$pubUrl");

  # execute
  my ($output, $exit) = Foswiki::Sandbox->sysCommand(
      $princeCmd, 
      BASEURL => $pubUrl,
      OUTFILE => $modacpdfFile->filename,
      INFILE => $htmlFile->filename,
      ERROR => $errorFile->filename,
    );

  local $/ = undef;

  my $error = '';
  if ($exit || TRACE) {
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

  my $attachment = $query->param('attachment') || 0;

  my $redirect = Foswiki::Func::getScriptUrl(
    'GenPDFPrincePlugin', 'getFile', 'rest',
    token => $token,
    wikiname => $wikiName,
    attachment => $attachment,
    basetopic => $baseTopic,
    baseweb => $baseWeb
  );
  Foswiki::Func::redirectCgiQuery( undef, $redirect );
  return;
}

###############################################################################
sub toFileUrl {
  my $url = shift;

  my $fileUrl = $url;

  if ($fileUrl =~ /^(?:https?:\/\/$Foswiki::cfg{DefaultUrlHost})?$Foswiki::cfg{PubUrlPath}(.*)$/) {
    $fileUrl = $1;
    $fileUrl =~ s/\?.*$//;
    if ($fileUrl =~ /^\/(.*)\/([^\/]+)\/[^\/]+$/) {
      my $web = $1;
      my $topic = $2;
      my $wikiName = Foswiki::Func::getWikiName();
      writeDebug("checking access for $wikiName on $web.$topic");
      return '' unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $topic, $web);
    }
    $fileUrl = "file://".$Foswiki::cfg{PubDir}.$fileUrl;
  } else {
    writeDebug("url=$url does not point to the local server");
  }

  writeDebug("url=$url, fileUrl=$fileUrl");
  return $fileUrl;
}

###############################################################################
sub _restGetFile {
  my ($session, $verb, $subject, $response) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $token = $query->param('token');
  my $baseTopic = $query->param('basetopic') || 'unknown';
  my $baseWeb = $query->param('baseweb') || 'unknown';
  my $wikiName = $query->param('wikiname');

  unless ($wikiName eq Foswiki::Func::getWikiName()) {
    my $heading = Foswiki::Func::expandCommonVariables('%MAKETEXT{"User mismatch for printout."}%');
    my $message = Foswiki::Func::expandCommonVariables('%MAKETEXT{"The PDF file you are trying to access was not created by you. This may have been caused by the browser cache. Please create a new PDF."}%');
    throw Foswiki::OopsException(
        'oopsgeneric',
        web => $baseWeb,
        topic => $baseTopic,
        params => [ $heading, $message ]
    );
  }

  my $modactmpDir = Foswiki::Func::getWorkArea( 'GenPDFPrincePlugin' );
  my $filename = "$modactmpDir/$wikiName$token.pdf";
  unless (-e $filename) {
    my $heading = Foswiki::Func::expandCommonVariables('%MAKETEXT{"Printout no longer available."}%');
    my $message = Foswiki::Func::expandCommonVariables('%MAKETEXT{"The PDF file you are trying to access is no longer available on the server. This may have been caused by the browser cache. Please create a new PDF."}%');
    throw Foswiki::OopsException(
        'oopsgeneric',
        web => $baseWeb,
        topic => $baseTopic,
        params => [ $heading, $message ]
    );
  }

  my $file; # note: can not use Foswiki::Func::readFile, because I need binary stuff
  unless (open ( $file, "<", $filename )) {
    my $heading = Foswiki::Func::expandCommonVariables('%MAKETEXT{"Error opening printout."}%');
    my $message = Foswiki::Func::expandCommonVariables('%MAKETEXT{"There was an error opening the PDF file. This is most likely due to a misconfiguration."}%');
    throw Foswiki::OopsException(
        'oopsgeneric',
        web => $baseWeb,
        topic => $baseTopic,
        params => [ $heading, $message ]
    );
  };
  binmode($file, ":raw");

  local $/;
  my $pdf = <$file>;

  close $file;
  unlink $filename;

  $response->body($pdf);
  $response->headers({
    'Content-Type' => 'application/pdf',
    'Content-Disposition' => (($query->param("attachment"))?'attachment':'inline') . ";filename=$baseTopic.pdf"
  });
  return;
}

sub maintenanceHandler {
    Foswiki::Plugins::MaintenancePlugin::registerCheck("GenPDFPrincePlugin:trace", {
        name => "GenPDFPlugin TRACE",
        description => "GenPDFPlugin's TRACE (debug mode) is active",
        check => sub {
            if(TRACE) {
                return {
                    result => 1,
                    priority => $Foswiki::Plugins::MaintenancePlugin::WARN,
                    solution => "Please edit Foswiki/Plugins/GenPDFPrincePlugin and set TRACE to 0."
                }
            } else {
                return { result => 0 };
            }
        }
    });
    Foswiki::Plugins::MaintenancePlugin::registerCheck("GenPDFPrincePlugin:workarea", {
        name => "Temporary files for GenPDFPlugin",
        description => "GenPDFPlugin's workarea containts garbage",
        check => sub {
            my $result = { result => 0 };
            my $modactmpDir = Foswiki::Func::getWorkArea( 'GenPDFPrincePlugin' );
            my @files = <$modactmpDir/*.{html,log,pdf}>;
            if ( scalar @files ) {
                $result->{result} = 1;
                $result->{priority} = $Foswiki::Plugins::MaintenancePlugin::WARN;
                $result->{solution} = "Please delete leftover pdf/log/html files in $modactmpDir";
            }
            return $result;
        }
    });
}

1;
