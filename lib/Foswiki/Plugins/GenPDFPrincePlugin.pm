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

sub initPlugin {
  if ($Foswiki::Plugins::VERSION < 2.0) {
    Foswiki::Func::writeWarning('Version mismatch between ',
    __PACKAGE__, ' and Plugins.pm');
    return 0;
  }

  return 1;
}


1;
