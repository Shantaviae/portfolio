#!/usr/bin/perl -w
use strict;
use CGI qw(:standard);
use DBI;

my $dbuser = "jcc333";
my $dbpasswd = "zOXm5qf6c";
my $debug = undef;

my $cookiename = "PortSideCookie";
my $inputcookiecontent = cookie($cookiename);
my $outputcookiecontent= undef;

my $user = undef;
my $password = undef;
my $logincomplain=0;
my $action= undef;

my @sqlinput = ();
my @sqloutput = ();

if(param("debug")) {
  $debug = param("debug");
}

#No matter what, we print the page header
print "Content-type: text/html\n\n";
print "<html>
        <head>
          <title>PortSide Financial Mgmt: Login</title>
          <link rel=\"stylesheet\" type=\"text/css\" href=\"portfolio.css\">
        </head>
        <body>
        <script type=\"javascript/text\" src=\"./scripts/jquery.js\"></script>
        <script type=\"javascript/text\" src=\"./scripts/master.js\"></script>";

#if the user is logged in, lead them to their overview page
if (defined($inputcookiecontent)) {
  ($user, $password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;
  print " <div style=\"text-align:center; border-style:solid; border-width:5px; border-color:#000080; width:30%; margin-left: auto ; margin-right: auto ; margin-top:50px;\">
      <h1>PortSide Login</h1>
      <h3>\"We have you logged in as $user\"</h3>
      <h3><a href=\"murphy.wot.eecs.northwestern.edu/~jcc333/portfolio/overview.pl?\">Proceed to the overview page.</a></h3>
</div>
  </body>
</html>";
}
#otherwise, let them log in or register
else {
  print " <div style=\"text-align:center; border-style:solid; border-width:5px; border-color:#000080; width:30%; margin-left: auto ; margin-right: auto ; margin-top:50px;\">
      <h1>PortSide Login</h1>
      <h3>\"because you should buy a boat\"</h3>
      <p>User Name: <input id=\"username\" type=\"text\"></p>
      <p>Password:&nbsp;&nbsp;&nbsp; <input id=\"password\" type=\"text\"></p>
      <p><input type=\"button\" value=\"All Aboard!\" onclick=postLogin(usernameFromPage(),passwordFromPage())></p>
      <p><a href=\"murphy.wot.eecs.northwestern.edu/~jcc333/portfolio/register.html\">Not signed up? Register!</a></p>
</div>
  </body>
</html>";
}

#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
  my ($id,$type,$headerlistref,@list)=@_;
  my $out;
  if ((defined $headerlistref) || ($#list>=0)) {
    $out="<table id=\"$id\" border>";
    if (defined $headerlistref) { 
      $out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
    }
    if ($type eq "ROW") { 
      $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
    } elsif ($type eq "COL") { 
      $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
    } else { 
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    }
    $out.="</table>";
  } else {
    $out.="(none)";
  }
  return $out;
}

# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
sub MakeRaw {
  my ($id, $type,@list)=@_;
  my $out;
  # Check to see if there is anything to output
  $out="<pre id=\"$id\">\n";
  # If it's a single row, just output it in an obvious way
  if ($type eq "ROW") { 
    # map {code} @list means "apply this code to every member of the list
    # and return the modified list.  $_ is the current list member
    $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } elsif ($type eq "COL") { 
    # ditto for a single column
    $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } else {
    # For a 2D table
    foreach my $r (@list) { 
      $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
      $out.="\n";
    }
  }
  $out.="</pre>\n";
  return $out;
}


sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  if ($debug) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
    push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  }
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set) and then die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    }
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    # if exec failed, record to sqlout and die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  # The rest assumes that the data will be forthcoming.
  my @data;
  if (defined $type and $type eq "ROW") { 
    @data=$sth->fetchrow_array();
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  my @ret;
  while (@data=$sth->fetchrow_array()) {
    push @ret, [@data];
  }
  if (defined $type and $type eq "COL") { 
    @data = map {$_->[0]} @ret;
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  $sth->finish();
  if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
  $dbh->disconnect();
  return @ret;
}

BEGIN {
  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
}

