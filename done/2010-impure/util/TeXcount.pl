#! /usr/bin/env perl
use strict;
use warnings;
use Term::ANSIColor;
#--- --- ---#
use POSIX qw(locale_h);
use locale;
setlocale(LC_CTYPE,"no_NO");

my $versionnumber="2.0";
my $versiondate="2008 Feb 10";

#--- --- ---#

### Macros for headers
# Macros that identify headers: i.e. following token or
# {...} is counted as header. The =>[2] indicates transition to
# state 2 which is used within headers (although the value is
# actually never used). This is copied to %TeXmacro and the
# only role of defining it here is that the counter for the number
# of headers is incremented by one.
my %TeXheader=('\title'=>[2],'\part'=>[2],'\chapter'=>[2],
               '\section'=>[2],'\subsection'=>[2],'\subsubsection'=>[2],
               '\paragraph'=>[2],'\subparagraph'=>[2]);

### How many tokens to gobble after macro
# Each macro is assumed to gobble up a given number of
# tokens (or {...} groups), as well as options [...] before, within
# and after. The %TeXmacro hash gives a link from a macro
# (or beginNAME for begin-end groups without the backslash)
# to either an integer giving the number of tokens to ignore
# or to an array (specified as [num,num,...]) of length N where
# N is the number of tokens to be read with the macro and the
# array values tell how each is to be interpreted (see the status
# values: 0=ignore, 1=count, etc.). Thus specifying a number N is
# equivalent to specifying an array [0,...,0] of N zeros.
#
# For macros not specified here, the default value is 0: i.e.
# no tokens are excluded, but [...] options are. Header macros
# specified in %TeXheader are automatically included here.
my %TeXmacro=(%TeXheader,
     '\documentclass'=>1,'\documentstyle'=>1,'\usepackage'=>1, '\hyphenation'=>1,
     '\pagestyle'=>1,'\thispagestyle'=>1, '\pagenumbering'=>1,'\markboth'=>1, '\markright'=>1,
     '\newcommand'=>[-3,-3],'\renewcommand'=>[-3,-3],
     '\newenvironment'=>[-3,-3,-3], 'renewenvironment'=>[-3,-3,-3],
     '\newfont'=>2,'\newtheorem'=>2,'\bibliographystyle'=>1, '\bibliography'=>1,
     '\parbox'=>1, '\marginpar'=>[3],'\makebox'=>0, '\raisebox'=>1, '\framebox'=>0,
     '\newsavebox'=>1, '\sbox'=>1, '\savebox'=>2, '\usebox'=>1,'\rule'=>2,
     '\footnote'=>[3],'\label'=>1, '\ref'=>1, '\pageref'=>1, '\bibitem'=>1,
     '\cite'=>1, '\citep'=>1, '\citet'=>1, '\citeauthor'=>1, '\citealt'=>1, '\nocite'=>1,
     '\eqlabel'=>1, '\eqref'=>1,'\hspace'=>1, '\vspace'=>1, '\addvspace'=>1,
     '\input'=>1, '\include'=>1, '\includeonly'=>1,'\includegraphics'=>1,
     '\newlength'=>1, '\setlength'=>2, '\addtolength'=>2,'\settodepth'=>2,
     '\settoheight'=>2, '\settowidth'=>2,'\newcounter'=>1, '\setcounter'=>2,
     '\addtocounter'=>2,'\stepcounter'=>1, '\refstepcounter'=>1, '\usecounter'=>1,
     '\alph'=>1, '\arabic'=>1, '\fnsymbol'=>1, '\roman'=>1, '\value'=>1,
     '\cline'=>1, '\multicolumn'=>3,'\typeout'=>1, '\typein'=>1,
     'beginlist'=>2, 'beginminipage'=>1, 'begintabular'=>1,
     'beginthebibliography'=>1,'beginlrbox'=>1,
     '\begin'=>1,'\end'=>1,'\title'=>[2]);

### Macros that should be counted as one or more words
# Macros that represent text may be declared here. The value gives
# the number of words the macro represents.
my %TeXmacroword=('\LaTeX'=>1,'\TeX'=>1);

### Macros that are counted within the preamble
# The preamble is the text between \documentclass and \begin{document}.
# Text and macros in the preamble is ignored unless specified here. The
# value is the status (1=text, 2=header, etc.) they should be interpreted as.
# Note that only the first unit (token or {...} block) is counted.
my %TeXpreamble=('\title'=>[2],
     '\newcommand'=>[-3,-3],'\renewcommand'=>[-3,-3],
     '\newenvironment'=>[-3,-3,-3], 'renewenvironment'=>[-3,-3,-3],
     );

### Begin-End groups
# Identified as begin-end groups, and define =>state. The
# states used corresponds to the elements of the count array, and
# are:
#    0: Not included
#    1: Text, word included in text count
#    2: Header, words included in header count
#    3: Float caption, words included in float caption count
#    6: Inline mathematics, words not counted
#    7: Displayed mathematics, words not counted
#   -1: Float, not included, but looks for captions
#
#    4 and 5 are used to count number of headers and floats
#    and are not used as states.
#
# Groups that are not defined will be counted as the surrounding text.
#
# Note that some environments may only exist within math-mode, and
# therefore need not be defined here: in fact, they should not as it
# is not clear if they will be in inlined or displayed math.
#
my %TeXgroup=('document'=>1,'letter'=>1,'titlepage'=>0,
     'center'=>1,'flushleft'=>1,'flushright'=>1,
     'abstract'=>1,'quote'=>1,'quotation'=>1,'verse'=>1,'minipage'=>1,'verbatim'=>1,
     'description'=>1,'enumerate'=>1,'itemize'=>1,'list'=>1,
     'theorem'=>1,'lemma'=>1,'definition'=>1,'corollary'=>1,'example'=>1,
     'math'=>6,'displaymath'=>7,'equation'=>7,'eqnarray'=>7,
     'figure'=>-1,'float'=>-1,'picture'=>-1,'table'=>-1,
     'tabbing'=>0,'tabular'=>0,'thebibliography'=>0,'lrbox'=>0);

### In floats: include only specific macros
# Macros used to identify caption text within floats.
my %TeXfloatinc=('\caption'=>[3]);

### Macros for including tex files
# Allows \macro{file} or \macro file. If the value is 1, the filetype .tex will
# be added if file is without a filetype; if the value is 0, this will not be
# done.
my %TeXfileinclude=('\input'=>0,'\include'=>1);

### Count labels
# Labels used to describe the counts
my @countlabel=('Files','Words in text','Words in headers',
      'Words in float captions','Number of headers','Number of floats',
      'Number of math inlines','Number of math displayed');

# Styles
my @STYLES=();
my %STYLE;
$STYLES[0]={'error'=>'bold red'};
$STYLES[1]={%{$STYLES[0]},
            'word1'=>'blue','word2'=>'bold blue','word3'=>'blue',
            'grouping'=>'red','document'=>'red','mathgroup'=>'magenta',
            'state'=>'cyan underline'};
$STYLES[2]={%{$STYLES[1]},
            'word0'=>'yellow','word-1'=>'yellow',
            'command'=>'green','exclgroup'=>'yellow','exclmath'=>'yellow',
            'ignore'=>'cyan'};
$STYLES[3]={%{$STYLES[2]},
            'tc'=>'bold yellow','comment'=>'yellow','option'=>'yellow','fileinclude'=>'bold green'};
$STYLES[4]={%{$STYLES[3]}};

# Options and states
my $verbose=0;
my $showstates=0;
my $htmlstyle=0;
my $blankline=0;
my $includeTeX=0;
my $briefsum=0;

#--- --- ---#

## SHORT HELP AND INFO
if (!defined @ARGV) {
  print_version();
  print_syntax();
  print_reference();
  exit;
} elsif ($ARGV[0]=~/^(\-(h|\?|\-?help)|\/\?)$/) {
  print_help();
  exit;
} elsif ($ARGV[0]=~/^\-?\-version$/) {
  print_version();
  exit;
} elsif ($ARGV[0]=~/^\-?\-license$/) {
  print_license();
  exit;
}

# PROCESS ARGUMENTS AND FILES
my $totalcount=new_count();
my @toplevelfiles;
my @filelist;
foreach my $arg (@ARGV) {
  if ($arg eq '-noinc') {$includeTeX=0; next;}
  if ($arg eq '-inc') {$includeTeX=1; next;}
  if ($arg eq '-brief') {$briefsum=1; next;}
  if ($arg eq '-v0') {$verbose=0; next;}
  if ($arg eq '-v1') {$verbose=1; next;}
  if ($arg eq '-vv' || $arg eq '-v2') {$verbose=2; next;}
  if ($arg eq '-vvv' || $arg eq '-v3' || $arg eq '-v') {$verbose=3; next;}
  if ($arg eq '-vvvv' || $arg eq '-v4') {$verbose=3; $showstates=1; next;}
  if ($arg =~ /^\-showstate/ ){$showstates=1; next;}
  if ($arg =~ /^\-html/ ) {
    $ENV{'ANSI_COLORS_DISABLED'} = 1;
    $htmlstyle = $arg eq '-htmlcore' ? 1 : 2;
    if ($htmlstyle>1) {html_head();}
    next;
  }
  if ($arg=~/^\-(nocol|nc$)/) {
    $ENV{'ANSI_COLORS_DISABLED'} = 1;
    next;
  }
  if ($arg=~/^\-/) {
    print 'Invalid opton '.$arg."\n";
    print_syntax();
    exit;
  }
  $arg=~s/\\/\//g;
  push @toplevelfiles,$arg;
}
%STYLE=%{$STYLES[$verbose]};
for my $file (<@toplevelfiles>) {
  @filelist=($file);
  foreach my $f (@filelist) {
    my $tex=TeXfile($f);
    my $fpath=$f;
    $fpath=~s/^(.*[\\\/])[^\\\/]+/$1/;
    if (!defined $tex) {
      print "File not found or not readable: ".$f."\n";
    } else {
      parse($tex);
      print "\n";
      print_count($tex->{'count'},'FILE: '.$f);
      print "\n";
      add_count($totalcount,$tex->{'count'});
    }
  }
}
if (${$totalcount}[0]>1) {
  print "\n";
  formatprint('Total','h1');
  print_count($totalcount,'SUM');
}
if ($htmlstyle>1) {
  html_tail();
}



#########
######### Subroutines
#########

sub TeXfile {
  my $filename=shift @_;
  my $file=read_file($filename) || return undef;
  return TeXcode($file,$filename);
}

sub TeXcode {
  my ($texcode,$filename)=@_;
  my %TeX=();
  $TeX{'filename'}=$filename;
  if (!defined $filename) {
    $TeX{'filepath'}='';
  } elsif ($filename=~/^(.*[\\\/])[^\\\/]+$/) {
    $TeX{'filepath'}=$1;
  } else {
    $TeX{'filepath'}='';
  }
  $TeX{'line'}=$texcode;
  $TeX{'next'}=undef;
  $TeX{'type'}=undef;
  $TeX{'style'}=undef;
  $TeX{'printstate'}=undef;
  $TeX{'eof'}=0;
  $TeX{'count'}=new_count();
  $TeX{'count'}[0]++;
  return \%TeX;
}

sub set_style {
  my ($tex,$style)=@_;
  if (!(($tex->{'style'}) && ($tex->{'style'} eq '-'))) {$tex->{'style'}=$style;}
}

sub flush_style {
  my ($tex,$style)=@_;
  set_style($tex,$style);
  flush_next($tex);
}

sub line_return {
  my $blank=shift @_;
  if ($blank>$blankline) {
    if ($htmlstyle) {print "<br>\n";} else {print "\n";}
    $blankline++;
  }
}

sub print_style {
  my ($text,$style,$state)=@_;
  (($verbose>=0) && (defined $text) && (defined $style)) || return;
  my $colour;
  ($colour=$STYLE{$style}) || return;
  if (($colour) && !($colour eq '-')) {
    if ($htmlstyle) {
      print "<span class='".$style."'>".$text."</span>";
    } else {
      print Term::ANSIColor::colored($text,$colour);
    }
    if ($state) {
      print_style($state,'state');
    }
    $blankline=-1;
  }
}

sub print_error {
  my $text=shift @_;
  line_return(1);
  print_style("###  ".$text."  ###",'error');
  line_return(1);
}

sub formatprint {
  my ($text,$tag,$class)=@_;
  my $break=($text=~s/\n$//);
  if ($htmlstyle && defined $tag) {
    print '<'.$tag;
    if ($class) {print " class='".$class."'";}
    print '>'.$text.'</'.$tag.'>';
  } else {
    print $text;
  }
  if ($break) {print "\n";}
}

sub read_file {
  my $filename=shift @_;
  open(FH,"<".$filename."") || return undef;
  if ($verbose) {
    #line_return(1);
    formatprint("File: ".$filename."\n",'h2');
    $blankline=0;
  }
  my @text=();
  while (my $line=<FH>) {
    push @text,$line;
  }
  close(FH);
  return join('',@text);
}

sub next_token {
  my $tex=shift @_;
  my ($next,$type);
  if (defined $tex->{'next'}) {print_style($tex->{'next'}.' ',$tex->{'style'});}
  $tex->{'style'}=undef;
  while (defined ($next=get_next_token($tex))) {
    $type=$tex->{'type'};
    if ($type==0) {
      print_style($next,'comment');
    } elsif ($type==9) {
      if ($verbose) {line_return(1);}
    } else {
      return $next;
    }
  }
  return $next;
}

sub flush_next {
  my $tex=shift @_;
  if (defined $tex->{'next'}) {
    print_style($tex->{'next'}.' ',$tex->{'style'},$tex->{'printstate'});
  }
  $tex->{'printstate'}=undef;
  $tex->{'style'}='-';
}

sub get_next_token {
  # Token (or token group) category:
  #   0: comment
  #   1: word (or other forms of text or text components)
  #   2: symbol (not word, e.g. punctuation)
  #   3: macro
  #   4: curly braces {}
  #   5: brackets []
  #   6: maths
  #   999: end of line or blank line
  #   666: TeXcount instruction (%TC:instruction)
  my $tex=shift @_;
  my $next;
  (defined ($next=get_token($tex,'\%+TC:[^\n]*',666))) && return $next;
  (defined ($next=get_token($tex,'\%[^\n]*',0))) && return $next;
  (defined ($next=get_token($tex,'\n',9))) && return $next;
  (defined ($next=get_token($tex,'\\\\[\{\}]',2))) && return $next;
  (defined ($next=get_token($tex,'(\w+\.)+\w+\.?',1))) && return $next;
  (defined ($next=get_token($tex,'\w+([\-\']\w+)*',1))) && return $next;
  (defined ($next=get_token($tex,'[\"\'\`:\.,\(\)\[\]!\+\-\*=/\^\_\@\<\>\~\#\&]',2))) && return $next;
  (defined ($next=get_token($tex,'\\\\([a-zA-Z_]+|[^a-zA-Z_])',3))) && return $next;
  (defined ($next=get_token($tex,'[\{\}]',4))) && return $next;
  (defined ($next=get_token($tex,'[\[\]]',5))) && return $next;
  (defined ($next=get_token($tex,'\$\$',6))) && return $next;
  (defined ($next=get_token($tex,'\$',6))) && return $next;
  (defined ($next=get_token($tex,'.',999))) && return $next;
  (defined ($next=get_token($tex,'[^\s]+',999))) && return $next;
  $tex->{'eof'}=1;
  return undef;
}

sub get_token {
  my ($tex,$regexp,$type)=@_;
  if (!defined $regexp) {print_error("ERROR in get_token: undefined regex.");}
  if (!defined $tex->{'line'}) {print_error("ERROR in get_token: undefined tex-line. ".$tex->{'next'});}
  if ( $tex->{'line'} =~ s/^($regexp)[ \t\r\f]*// ) {
    $tex->{'next'}=$1;
    $tex->{'type'}=$type;
    return $1;
  }
  return undef;
}

sub new_count {
  my @count=(0,0,0,0,0,0,0,0);
  # files, text words, header words, float words,
  # headers, floats, math-inline, math-display;
  return \@count;
}

sub count_word {
  my ($count,$type,$word,$style,$verb)=@_;
  ($word) || ($word="");
  ($style) || ($style=0);
  ($verb) || ($verb=0);
  if ($type>0) {${$count}[$type]++;}
  if ($verb >= $verbose) {
  }
}

sub print_count {
  my ($count,$header)=@_;
  if ($briefsum) {
    if ($htmlstyle) {print "<p class='count'>\n";}
    print ${$count}[1]."+".${$count}[2]."+".${$count}[3].
        " (".${$count}[4]."/".${$count}[5]."/".${$count}[6]."/".${$count}[7].") ".
        $header;
    if ($htmlstyle) {print "</p>\n";}
    return;
  }
  if ($htmlstyle) {print "<dl class='count'>\n";}
  if (defined $header) {
    formatprint($header."\n",'dt','header');
  }
  for (my $i=1;$i<8;$i++) {
    formatprint($countlabel[$i].': ','dt');
    formatprint(${$count}[$i]."\n",'dd');
  }
  if ($htmlstyle) {print "</dl>\n";}
}

sub add_count {
  my ($a,$b)=@_;
  for (my $i=0;$i<8;$i++) {
   ${$a}[$i]+=${$b}[$i];
  }
}

sub parse {
  my ($tex)=@_;
  if ($htmlstyle && $verbose) {print "<p class=parse>\n";}
  while (!($tex->{'eof'})) {
    parse_unit($tex,1);
  }
  if ($htmlstyle && $verbose) {print "</p>\n";}
}

sub parse_unit {
  # Status:
  #    0 = exclude from count
  #    1 = text
  #    2 = header text
  #    3 = float text
  #   -1 = float (exclude)
  #   -2 = strong exclude, ignore begin-end groups
  #   -3 = stronger exclude, do not parse macro parameters
  #   -9 = preamble (between \documentclass and \begin{document})
  my ($tex,$status,$end)=@_;
  if (!defined $status) {
    print_error("CRITICAL ERROR: Undefined parser status!");
    exit;
  } elsif (ref($status) eq 'ARRAY') {
    print_error("CRITICAL ERROR: Invalid parser status!");
    exit;
  }
  my $count=$tex->{'count'};
  my $substat;
  if ($showstates) {
    if (defined $end) {
      $tex->{'printstate'}=':'.$status.':'.$end.':';
    } else {
      $tex->{'printstate'}=':'.$status.':';
    }
    flush_next($tex);
  }
  while (defined (my $next=next_token($tex))) {
    # parse next token; or tokens until match with $end
    set_style($tex,"ignore");
    if ((defined $end) && ($end eq $next)) {
      # end of unit
      return;
    } elsif (!defined $next) {
      print_error("ERROR: End of file while waiting for ".$end);
      return;
    }
    if ($status==-9 && $next eq '\begin' && $tex->{'line'}=~/^\{\s*document\s*\}/) {
      # \begin{document}
      $status=1;
    }
    if ($next eq '\documentclass') {
      # starts preamble
      set_style($tex,'document');
      gobble_option($tex);
      gobble_macro_parms($tex,1);
      while (!($tex->{'eof'})) {
       parse_unit($tex,-9);
      }
    } elsif ($tex->{'type'}==666) {
      # parse TC instructions
      parse_tc($tex);
    } elsif ($tex->{'type'}==1) {
      # word
      if ($status>0) {
        ${$count}[$status]++;
        set_style($tex,'word'.$status);
      }
    } elsif ($next eq '{') {
      # {...}
      parse_unit($tex,$status,'}');
    } elsif ($tex->{'type'}==3 && $status==-3) {
      set_style($tex,'ignore');
    } elsif ($tex->{'type'}==3) {
      # macro call
      set_style($tex,'command');
      if ($next eq '\begin' && $status!=-2) {
      	parse_begin_end($tex,$count,$status);
      } elsif (($status==-1) && ($substat=$TeXfloatinc{$next})) {
        # text included from float
        gobble_macro_parms($tex,$substat);
      } elsif ($status==-9 && defined ($substat=$TeXpreamble{$next})) {
      	# parse preamble include macros
      	if (defined $TeXheader{$next}) {${$count}[4]++;}
        gobble_macro_parms($tex,$substat,1);
      } elsif ($status<0) {
      	# ignore
        gobble_option($tex);
      } elsif ($next eq '\(') {
        # math inline
        parse_math($tex,$count,$status,6,'\)');
      } elsif ($next eq '\[') {
        # math display
        parse_math($tex,$count,$status,7,'\]');
      } elsif ($next eq '\def') {
        # ignore \def...
        $tex->{'line'} =~ s/^([^\{]*)\{/\{/;
        flush_next($tex);
        print_style($1.' ','ignore');
        parse_unit($tex,-2);
      } elsif (defined (my $addsuffix=$TeXfileinclude{$next})) {
      	# include file: queue up for parsing
      	parse_include_file($tex,$count,$status,$addsuffix);
      } elsif (defined ($substat=$TeXmacro{$next})) {
        # macro: exclude options
      	if (defined $TeXheader{$next}) {${$count}[4]++;}
        gobble_macro_parms($tex,$substat,$status);
      } elsif (defined ($substat=$TeXmacroword{$next})) {
      	# count macro as word (or a given number of words)
        ${$count}[$status]+=$substat;
        set_style($tex,'word'.$status);
      } elsif ($next =~ /^\\[^\w\_]/) {
      } else {
        gobble_option($tex);
      }
    } elsif ($next eq '$') {
      # math inline
      parse_math($tex,$count,$status,6,'$');
    } elsif ($next eq '$$') {
      # math display (unless already in inlined math)
      if (! $end eq '$') {parse_math($tex,$count,$status,7,'$$');}
    }
    if (!defined $end) {return;}
  }
}

sub gobble_option {
  my $tex=shift @_;
  flush_next($tex);
  if ($tex->{'line'} =~ s/^(\[(\w|[,\-\s\~\.\:\;\+\?\*\_\=])*\])//) {
    print_style($1,'option');
    return $1;
  }
  return undef;
}

sub parse_tc {
  my ($tex)=@_;
  set_style($tex,'tc');
  if ($tex->{'next'}=~/^\%+TC:\s*(\w+)\s+([\\]*\w+)\s+([^\s\n]+)(\s+([0-9]+))?/) {
    my $instr=$1;
    my $macro=$2;
    my $param=$3;
    my $option=$5;
    if ($param=~/^\[([0-9,]+)\]$/) {$param=[split(',',$1)];}
    if (($instr eq 'macro') || ($instr eq 'exclude')) {$TeXmacro{$macro}=$param;}
    elsif ($instr eq 'header') {$TeXheader{$macro}=$param;$TeXmacro{$macro}=$param;}
    elsif ($instr eq 'macroword') {$TeXmacroword{$macro}=$param;}
    elsif ($instr eq 'preambleinclude') {$TeXpreamble{$macro}=$param;}
    elsif ($instr eq 'group') {$TeXmacro{'begin'.$macro}=$param;$TeXgroup{$macro}=$option;}
    elsif ($instr eq 'floatinclude') {$TeXfloatinc{$macro}=$param;}
    elsif ($instr eq 'fileinclude') {$TeXfileinclude{$macro}=$param;}
    else {print_error("Warning: Unknown TC command: ".$instr);}
  } elsif ($tex->{'next'}=~/^\%+TC:\s*(\w+)/) {
    my $instr=$1;
    print_error("Warning: Unknown TC command: ".$instr);
  }
}

sub parse_math {
  my ($tex,$count,$status,$substat,$end)=@_;
  my $localstyle=$status>0 ? 'mathgroup' : 'exclmath';
  if ($status>0) {${$count}[$substat]++;}
  set_style($tex,$localstyle);
  parse_unit($tex,0,$end);
  set_style($tex,$localstyle);
}

sub parse_begin_end {
  my ($tex,$count,$status)=@_;
  my $localstyle=$status>0 ? 'grouping' : 'exclgroup';
  flush_style($tex,$localstyle);
  gobble_option($tex);
  my $groupname;
  if ($tex->{'line'} =~ s/^\{\s*([^\{\}]+)\s*\*?\}[ \t\r\f]*//) {
    # gobble group type
    $groupname=$1;
    print_style('{'.$1.'}',$localstyle);
    my $next='begin'.$1;
    if (defined (my $substat=$TeXmacro{$next})) {
      gobble_macro_parms($tex,$substat);
    }
  } else {
    print_error("Warning: BEGIN group without type.");
  }
  # find group status (or leave unchanged)
  my $substat;
  defined ($substat=$TeXgroup{$1}) || ($substat=$status);
  if ($status<=0 && $status<$substat) {$substat=$status;}
  if (($status>0) && ($substat==-1)) {
    # Count float
    ${$count}[5]++;
  }
  if ($status>0 and $substat>3) {
    # count item, exclude contents
    ${$count}[$substat]++;
    $substat=0;
  }
  parse_unit($tex,$substat,'\end');
  if ($tex->{'line'} =~ s/^\{\s*([^\{\}]+)\s*\}[ \t\r\f]*//) {
    # gobble group type
    flush_style($tex,$localstyle);
    print_style('{'.$1.'}',$localstyle);
  } else {
    print_error("Warning: END group without type while waiting to end ".$groupname.".");
  }
}

sub parse_include_file {
  my ($tex,$count,$status,$addsuffix)=@_;
  $tex->{'line'} =~ s/^\{([^\{\}\s]+)\}// ||
    $tex->{'line'} =~ s/^\s*([^\{\}\%\\\s]+)// ||
    return;
  flush_next($tex);
  if ($status>0) {
    print_style($&,'fileinclude');
    my $fname=$1;
    if ($addsuffix && ($fname=~/^[^\.]+$/)) {$fname.='.tex';}
    if ($includeTeX) {push @filelist,$tex->{'filepath'}.$fname;}
  } else {
    print_style($&,'ignored');
  }
}

sub gobble_options {
  while (gobble_option(@_)) {}
}

sub gobble_macro_modifier {
  my $tex=shift @_;
  flush_next($tex);
  if ($tex->{'line'} =~ s/^\*//) {
    print_style($1,'option');
    return $1;
  }
  return undef;
}

sub gobble_macro_parms {
  my ($tex,$parm,$oldstat)=@_;
  my $i;
  if (ref($parm) eq 'ARRAY') {
    $i=scalar @{$parm};
  } else {
    $i=$parm;
    $parm=[0,0,0,0,0,0,0,0,0];
  }
  if ($i>0) {gobble_macro_modifier($tex);}
  gobble_options($tex);
  for (my $j=0;$j<$i;$j++) {
    parse_unit($tex,new_status($parm->[$j],$oldstat));
    gobble_options($tex);
  }
}

sub new_status {
  my ($substat,$old)=@_;
  if (!defined $old) {return $substat;}
  if ($old==-3 || $substat==-3) {return -3;}
  if ($old==-2 || $substat==-2) {return -2;}
  if ($old==0 || $substat==0) {return 0;}
  if ($old==-9 || $substat==-9) {return -9;}
  if ($old>$substat) {return $old;}
  return $substat;
}

### HTML context

sub html_head {
  print '
<html>
<head>
<style>
<!--
body {width:100%;padding:5;margin:5 10 5 5;}
.error {font-weight:bold;color:#f00;font-style:italic;}
.parse {font-size: 80%; background: #eef;}
.word1,.word2,.word3 {color: #009;}
.word2 {font-weight: 700;}
.word3 {font-style: italic;}
.word-1 {color: #66c;}
.command {color: #c00;}
.option {color: #cc0;}
.grouping, .document {color: #900; font-weight:bold;}
.mathgroup {color: #090;}
.exclmath {color: #6c6;}
.ignore {color: #999;}
.exclgroup {color:#c66;}
.tc {color: #999; font-weight:bold;}
.comment {color: #999; font-style: italic;}
.state {color: #990; font-size: 70%;}
.fileinclude {color: #696; font-weight:bold;}
dl.count {background: #cfc; color: 009;}
dl.count dt.header {font-weight: 700; font-style: italic; float: none;}
dl.count dt {clear: both; float: left;}
dl.count dd {font-weight: 700;}
.warning {color: #c00; font-weight: 700;}
.parse, .count {border: solid 1px #999; margin: 0pt; padding: 4pt;}
.parse {border-bottom:none;}
-->
</style>
</head>
<body>
<h1>LaTeX word count</h1>
';
}

sub html_tail {
  print '</body></html>';
}


### HELP AND INFO

sub print_version {
  print "TeXcount version ".$versionnumber.", ".$versiondate.'.';
}

sub print_syntax {
  print '
Syntax: TeXcount.pl [options] files

Options:
  -v            Verbose (same as -v3)
  -v0           Do not present parsing details
  -v1           Verbose: print parsed words, mark formulae
  -v2           More verbose: also print ignored text
  -v3           Even more verbose: include comments and options
  -showstate    Show internal states (with verbose)
  -brief        Only prints a brief, one line summary of counts
  -nc, -nocol   No colours (colours require ANSI)
  -inc          Include tex files included in the document
  -noinc        Do not include included tex files (default)
  -html         Output in HTML format
  -htmlcore     Only HTML body contents
  -h, -?, --help, /?   Help
  --version     Print version number
  --license     License information
';
}

sub print_help {
  print '
***************************************************************
*   TeXcount.pl '.$versionnumber.', '.$versiondate.'
*

Count words in TeX and LaTeX files, ignoring macros, tables,
formulae, etc.
';
  print_syntax();
  print '
The script counts words as either words in the text, words in
headers/titles or words in floats (figure/table captions).
Macro options (i.e. \marco[...]) are ignored; macro parameters
(i.e. \macro{...}) are counted or ignored depending on the
macro, but by default counted. Begin-end groups are by default
ignored and treated as \'floats\', though some (e.g. center) are
counted.

Unless -nocol (or -nc) has been specified, the output will be
colour coded. Counted text is coloured blue with headers are in
bold and in HTML output caption text is italicised.

Mathematical formulae are not counted as words, but are instead
counted separately with separate counts for inlined formulae
and displayed formulae. Similarly, the number of headers and
the number of \'floats\' are counted. Note that \'float\' is used
here to describe anything defined in a begin-end group unless
explicitly recognized as text or mathematics.

The verbose options (-v1, -v2, -v3, showstate) produces output
indicating how the text has been interpreted. Check this to
ensure that words in the text has been interpreted as such,
whereas mathematical formulae and text/non-text in begin-end
groups have been correctly interpreted.

Unix hint: Use \'less -r\' instead of just \'less\' to view output:
the \'-r\' option makes less treat text formating codes properly.

Windows hint: If your Windows interprets ANSI colour codes, lucky
you! Otherwise, use the -nocol (or -nc) option with the verbose
options or the output will be riddled with colour codes. Instead,
you can use -html to produce HTML code, write this to file and
view with your favourite browser.
';
  print_reference();
}

sub print_reference {
  print '
The TeXcount script is copyright of Einar Andreas R�dland (2008)
and published under the LaTeX Project Public License.

For more information about the script, e.g. news, updates, help,
usage tips, known issues and short-comings, go to
    http://folk.uio.no/einarro/Comp/texwordcount.html
or go to
    http://folk.uio.no/einarro/Services/texcount.html
to access the script as a web service. Feedback such as problems
or errors can be reported to einarro@ifi.uio.no.
';
}

sub print_license {
  print 'TeXcount version '.$versionnumber.'
  
Copyright 2008 Einar Andreas R�dland

The TeXcount script is published under the LaTeX Project Public
License (LPPL)
    http://www.latex-project.org/lppl.txt
which grants you, the user, the right to use, modify and distribute
the script. However, if the script is modified, you must change its
name or use other technical means to avoid confusion.

The script has LPPL status "maintained" with Einar Andreas
R�dland being the current maintainer.
';
}
