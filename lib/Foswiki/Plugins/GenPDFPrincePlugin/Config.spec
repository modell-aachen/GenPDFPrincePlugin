# ---+ Extensions
# ---++ GenPDFPrincePlugin
# **PATH M**
# prince executable including complete path
# downloadable from http://www.princexml.com/
$Foswiki::cfg{GenPDFPrincePlugin}{PrinceCmd} = '/usr/bin/prince --baseurl %BASEURL|U% -i html -o %OUTFILE|F% %INFILE|F%';
1;
