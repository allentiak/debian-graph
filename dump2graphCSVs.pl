#!/usr/bin/perl

# $1: UDD dump file


use utf8;
use Data::Dumper;
use UUID 'uuid';
use Dpkg::Version;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 0;  # stable output
$Data::Dumper::Purity = 0; # recursive structures must be safe

my @srcdeps = qw/build_depends build_depends_indep build_conflicts build_conflicts_indep/;
my @bindeps = qw/depends recommends suggests conflicts breaks provides replaces pre_depends enhances/;


(my $self = $0) =~ s#.*/##;
my %data;

my $destdir = "ddb";

if ( -r "$destdir/node-vsp.csv") { die "Files already present in $destdir!" };

# DEBUG
#
#open my $fh, "<:encoding(UTF-8)", "packages.csv" or die "sources.csv: $!";
#$csv->column_names($csv->getline($fh));
#my $foo = $csv->getline_hr($fh);
#close($fh);
#for my $k (sort keys %$foo) {
#  print "$k = $foo->{$k}\n";
#}
#print "FINISHED READING\n\n";
#open(my $fd, ">", "debian-packages-udd.dump") || die("Cannot open 'debian-packages-udd.dump' for writing: $!");
#print $fd Data::Dumper->Dump([$foo], [qw(foo)]);
#close($fd);

print "Reading UDD dump from $1...\n";

$in_filename =~ s#^(\s)#./$1#;
open(my $in, "< $in_filename\0") || die "Can't open $in_filename: $!";

my $vars;
{
  undef $/;
  $vars = <$in>;
}
close($in);
my $source;
my $packages;
eval $vars;

print "Working on binary packages ...\n";
read_packages_file();
print "Working on source packages ...\n";
read_sources_file();

print "Generating files ...\n";
generate_files();
print "Done.\n";

# DEBUG
#
#open(my $fd, ">", "debian.dump") || die("Cannot open debian.dump: $!");
#print $fd Data::Dumper->Dump([\%data], [qw(data)]);
#close($fd);

exit(0);



# Auxiliary functions

sub myuuid {
  my $foo = uuid();
  $foo =~ s/-//g;
  return "id$foo";
}

sub generate_files {
  my %fd;
  for my $f (qw/sp vsp bp vbp mnt suite altdeps/) {
    open($fd{$f}, ">:encoding(UTF-8)", "$destdir/node-$f.csv") || die("Cannot open $destdir/node-$f.csv: $!");
  }
  print { $fd{'sp'}    } "uuid:ID,name\n";
  print { $fd{'vsp'}   } "uuid:ID,name,version\n";
  print { $fd{'bp'}    } "uuid:ID,name\n";
  print { $fd{'vbp'}   } "uuid:ID,name,version\n";
  print { $fd{'mnt'}   } "uuid:ID,name,email\n";
  print { $fd{'suite'} } "uuid:ID,name\n";
  print {$fd{'altdeps'}} "uuid:ID,name\n";
  # sp and vsp
  for my $sp (keys(%{$data{'source'}})) {
    for my $v (keys(%{$data{'source'}{$sp}})) {
      next if ($v eq 'uuid');
      my $b = $data{'source'}{$sp}{$v}{'uuid'} = myuuid();
      print { $fd{'vsp'} } "$b,$sp,$v\n";
      for my $deptypes (@srcdeps) {
        for my $d (keys(%{$data{'source'}{$sp}{$v}{$deptypes}})) {
          my @list_of_altdeps = keys(%{$data{'source'}{$sp}{$v}{$deptypes}{$d}});
          if ($#list_of_altdeps > 0) {
            if (!defined($data{'altdeps'}{$d})) {
              $data{'altdeps'}{$d}{'uuid'} = myuuid();
            }
          }
        }
      }
    }
    my $a = $data{'source'}{$sp}{'uuid'} = myuuid();
    print { $fd{'sp'} } "$a,$sp\n";
  }
  # maintainers
  for my $m (keys(%{$data{'people'}})) {
    my $a = $data{'people'}{$m}{'uuid'} = myuuid();
    my $n = $data{'people'}{$m}{'name'};
    $n =~ s/"/\\"/g;
    print { $fd{'mnt'} } "$a,\"$n\",$m\n";
  }
  # suite
  for my $s (keys(%{$data{'suite'}})) {
    my $a = $data{'suite'}{$s}{'uuid'} = myuuid();
    print { $fd{'suite'} } "$a,$s\n";
  }
  # bp and vbp
  for my $bp (keys(%{$data{'bin'}})) {
    for my $v (keys(%{$data{'bin'}{$bp}})) {
      next if ($v eq 'uuid');
      my $b = $data{'bin'}{$bp}{$v}{'uuid'} = myuuid();
      print { $fd{'vbp'} } "$b,$bp,$v\n";
      for my $deptypes (@bindeps) {
        for my $d (keys(%{$data{'bin'}{$bp}{$v}{$deptypes}})) {
          my @list_of_altdeps = keys(%{$data{'bin'}{$bp}{$v}{$deptypes}{$d}});
          if ($#list_of_altdeps > 0) {
            if (!defined($data{'altdeps'}{$d})) {
              $data{'altdeps'}{$d}{'uuid'} = myuuid();
            }
          }
        }
      }
    }
    my $a = $data{'bin'}{$bp}{'uuid'} = myuuid();
    print { $fd{'bp'} } "$a,$bp\n";
  }
  # create the altdeps
  for my $ad (keys(%{$data{'altdeps'}})) {
    my $uuid = $data{'altdeps'}{$ad}{'uuid'};
    print { $fd{'altdeps'} } "$uuid,\"$ad\"\n"
  }
  #
  # now for the relations
  # vsp -builds-> vbp
  # vsp -is_instance_of-> sp
  # mnt -maintains-> vsp
  for my $deps (@srcdeps, @bindeps, qw/is_satisfied_by/) {
    open($fd{$deps}, ">:encoding(UTF-8)", "$destdir/edge-$deps.csv") || die("Cannot open $destdir/edge-$deps.csv: $!");
    print { $fd{$deps} } ":START_ID,reltype,relversion,:END_ID\n";
  }
  for my $f (qw/builds is_instance_of maintains contains next /) {
    open($fd{$f}, ">:encoding(UTF-8)", "$destdir/edge-$f.csv") || die("Cannot open $destdir/edge-$f.csv: $!");
    print { $fd{$f} } ":START_ID,:END_ID\n";
  }


  for my $sp (keys(%{$data{'source'}})) {
    my $spuuid = $data{'source'}{$sp}{'uuid'};
    # tree of version ordered
    my @srcvers;
    for my $v (keys(%{$data{'source'}{$sp}})) {
      next if ($v eq 'uuid');
      push @srcvers, Dpkg::Version->new($v);
    }
    my ($a, @rest) = sort @srcvers;
    for my $b (sort @rest) {
      my $auid = $data{'source'}{$sp}{$a->as_string()}{'uuid'};
      my $buid = $data{'source'}{$sp}{$b->as_string()}{'uuid'};
      print { $fd{'next'} } "$auid,$buid\n";
      $a = $b;
    }
    for my $v (keys(%{$data{'source'}{$sp}})) {
      next if ($v eq 'uuid');
      my $vspuuid = $data{'source'}{$sp}{$v}{'uuid'};
      # vsp -is_instance_of-> sp
      print { $fd{'is_instance_of'} } "$vspuuid,$spuuid\n";
      # mnt -maintains-> vsp
      my $mnt = $data{'source'}{$sp}{$v}{'maintainer'};
      my $mntuuid = $data{'people'}{$mnt}{'uuid'};
      if (!defined($mntuuid)) {
        print STDERR "Cannot find maintainer entry for $mnt with sp=$sp and v=$v\n";
      } else {
        print { $fd{'maintains'} } "$mntuuid,$vspuuid\n";
      }
      for my $deptypes (@srcdeps) {
        my $deps = $data{'source'}{$sp}{$v}{$deptypes};
        for my $d (keys %$deps) {
          my @list_of_altdeps = keys(%{$data{'source'}{$sp}{$v}{$deptypes}{$d}});
          if ($#list_of_altdeps > 0) {
            # this is an alternative dependency
            my $altdepuuid = $data{'altdeps'}{$d}{'uuid'};
            print { $fd{$deptypes} } "$vspuuid,none,1,$altdepuuid\n";
            for my $realdep (keys(%{$deps->{$d}})) {
              next if ($realdep eq 'uuid');
              my ($rel) = keys(%{$deps->{$d}{$realdep}});
              my $relver = $deps->{$d}{$realdep}{$rel};
              if (defined($data{'bin'}{$realdep})) {
                my $depbpuuid = $data{'bin'}{$realdep}{'uuid'};
                if ($depbpuuid) {
                  print { $fd{'is_satisfied_by'} } "$altdepuuid,$rel,$relver,$depbpuuid\n";
                } else {
                  print STDERR "Cannot find uuid for dep ==$realdep== at $d and $rel and $relver\n";
                }
              } else {
                # generate a new bp without any further information
                my $newuuid = $data{'bin'}{$realdep}{'uuid'} = myuuid();
                print { $fd{'bp'} } "$newuuid,$realdep\n";
                print { $fd{'is_satisfied_by'} } "$altdepuuid,$rel,$relver,$newuuid\n";
              }
            }
          } else {
            # this is a single dep
            my ($pkgdep) = keys(%{$deps->{$d}});
            my ($rel) = keys(%{$deps->{$d}{$pkgdep}});
            my $relver = $deps->{$d}{$pkgdep}{$rel};
            if (defined($data{'bin'}{$pkgdep})) {
              my $depbpuuid = $data{'bin'}{$pkgdep}{'uuid'};
              if ($depbpuuid) {
                print { $fd{$deptypes} } "$vspuuid,$rel,$relver,$depbpuuid\n";
              } else {
                print STDERR "Cannot find uuid for dep ==$pkgdep== at $d and $rel and $relver\n";
              }
            } else {
              # generate a new bp without any further information
              my $newuuid = $data{'bin'}{$pkgdep}{'uuid'} = myuuid();
              print { $fd{'bp'} } "$newuuid,$pkgdep\n";
              print { $fd{$deptypes} } "$vspuuid,$rel,$relver,$newuuid\n";
            }
          }
        }
      }
      # vsp -builds-> vbp
      for my $binpkg (keys(%{$data{'source'}{$sp}{$v}{'binary'}})) {
        # we cannot simply search for the same version number
        # due to binary rebuilds, which have version number:
        #  2222-4+... (part +....)
        # loop over the binary package versions,
        # strip any +.. part *AFTER* a - (that is in the debian version)
        my $found = 0;
        for my $bv (keys(%{$data{'bin'}{$binpkg}})) {
          my $shortv = $bv;
          $shortv =~ s/\+b[1-9][0-9]*$//;
          if ($shortv eq $v) {
            my $vbpuuid = $data{'bin'}{$binpkg}{$bv}{'uuid'};
            print { $fd{'builds'} } "$vspuuid,$vbpuuid\n";
            $found += 1;
          }
        }
        if ($found == 0) {
          # this can happen if we have *different* versions for different
          # architectures! Since I only read the data for amd64, there might
          # be sources that build a package for a different arch!
          #
          # Another reason is for udeb packages
          # here we need to check not only the Binaries field, but the
          # actual Package-List to make sure to only include non-udeb stuff!!!
          #
          # TODO - work on udeb packages
          #
          # TODO - how to integrate multiple architectures

          #print STDERR "Cannot find binary package for $sp : $v : $binpkg\n";
        #} elsif ($found > 1) {
        #  nothing unusual to have multiple versions! (testing and unstable bin rebuild)
        #  print STDERR "Found multiple matching bin package for $sp : $v!\n";
        }
      }
    }
  }
  #
  # vbp -is_instance_of-> bp
  # mnt -maintains-> vbp
  # vbp -next-> vbp
  for my $bp (keys(%{$data{'bin'}})) {
    my $bpuuid = $data{'bin'}{$bp}{'uuid'};
    # tree of version ordered
    my @binvers;
    for my $v (keys(%{$data{'bin'}{$bp}})) {
      next if ($v eq 'uuid');
      push @binvers, Dpkg::Version->new($v);
    }
    my ($a, @rest) = sort @binvers;
    for my $b (sort @rest) {
      my $auid = $data{'bin'}{$bp}{$a->as_string()}{'uuid'};
      my $buid = $data{'bin'}{$bp}{$b->as_string()}{'uuid'};
      print { $fd{'next'} } "$auid,$buid\n";
      $a = $b;
    }
    for my $v (keys(%{$data{'bin'}{$bp}})) {
      next if ($v eq 'uuid');
      my $vbpuuid = $data{'bin'}{$bp}{$v}{'uuid'};
      # vbp -is_instance_of-> bp
      print { $fd{'is_instance_of'} } "$vbpuuid,$bpuuid\n";
      #print { $fd{'is_instance_of'} } "$vbpuuid,$bpuuid #DEBUG: bp=$bp v=$v\n";
      # mnt -maintains-> vbp
      my $mnt = $data{'bin'}{$bp}{$v}{'maintainer'};
      my $mntuuid = $data{'people'}{$mnt}{'uuid'};
      if (!defined($mntuuid)) {
        print STDERR "Cannot find maintainer entry for $mnt with bp = $bp and v = $v\n";
      } else {
        print { $fd{'maintains'} } "$mntuuid,$vbpuuid\n";
      }
      for my $deptypes (@bindeps) {
        my $deps = $data{'bin'}{$bp}{$v}{$deptypes};
        for my $d (keys %$deps) {
          my @list_of_altdeps = keys(%{$data{'bin'}{$bp}{$v}{$deptypes}{$d}});
          if ($#list_of_altdeps > 0) {
            # this is an alternative dependency
            my $altdepuuid = $data{'altdeps'}{$d}{'uuid'};
            print { $fd{$deptypes} } "$vbpuuid,none,1,$altdepuuid\n";
            for my $realdep (keys(%{$deps->{$d}})) {
              next if ($realdep eq 'uuid');
              my ($rel) = keys(%{$deps->{$d}{$realdep}});
              my $relver = $deps->{$d}{$realdep}{$rel};
              if (defined($data{'bin'}{$realdep})) {
                my $depbpuuid = $data{'bin'}{$realdep}{'uuid'};
                if ($depbpuuid) {
                  print { $fd{'is_satisfied_by'} } "$altdepuuid,$rel,$relver,$depbpuuid\n";
                } else {
                  print STDERR "Cannot find uuid for dep ==$realdep== at $d and $rel and $relver\n";
                }
              } else {
                # generate a new bp without any further information
                my $newuuid = $data{'bin'}{$realdep}{'uuid'} = myuuid();
                print { $fd{'bp'} } "$newuuid,$realdep\n";
                print { $fd{'is_satisfied_by'} } "$altdepuuid,$rel,$relver,$newuuid\n";
              }
            }
          } else {
            # this is a single dep
            my ($pkgdep) = keys(%{$deps->{$d}});
            my ($rel) = keys(%{$deps->{$d}{$pkgdep}});
            my $relver = $deps->{$d}{$pkgdep}{$rel};
            if (defined($data{'bin'}{$pkgdep})) {
              my $depbpuuid = $data{'bin'}{$pkgdep}{'uuid'};
              if ($depbpuuid) {
                print { $fd{$deptypes} } "$vbpuuid,$rel,$relver,$depbpuuid\n";
              } else {
                print STDERR "Cannot find uuid for dep ==$pkgdep== at $d and $rel and $relver\n";
              }
            } else {
              # generate a new bp without any further information
              my $newuuid = $data{'bin'}{$pkgdep}{'uuid'} = myuuid();
              print { $fd{'bp'} } "$newuuid,$pkgdep\n";
              print { $fd{$deptypes} } "$vbpuuid,$rel,$relver,$newuuid\n";
            }
          }
        }
      }


    }
  }
  # suite -contains-> vbp
  for my $s (keys(%{$data{'suite'}})) {
    my $suiteuuid = $data{'suite'}{$s}{'uuid'};
    for my $bp (keys(%{$data{'suite'}{$s}{'pkgs'}})) {
      my $v = $data{'suite'}{$s}{'pkgs'}{$bp};
      my $vbpuuid = $data{'bin'}{$bp}{$v}{'uuid'};
      print { $fd{'contains'} } "$suiteuuid,$vbpuuid\n";
    }
  }
  #
  # close all files
  for my $f (qw/sp vsp bp vbp mnt suite altdeps/) {
    close($fd{$f}) || warn("Cannot close $f.csv: $!");
  }
  for my $f (@srcdeps, @bindeps, qw/is_satisfied_by/) {
    close($fd{$f}) || warn("Cannot close $f.csv: $!");
  }
  for my $f (qw/builds is_instance_of maintains contains/) {
    close($fd{$f}) || warn("Cannot close $f.csv: $!");
  }
}


# format
# $data{'source'}{$srcpkg}{$version}{'binary'}{$binpkgname} = 1
# $data{'source'}{$srcpkg}{$version}{'maintainer'} = "..."
# $data{'source'}{$srcpkg}{$version}{'uploaders'}{$email} = 1
# $data{'source'}{$srcpkg}{$version}{'section'} = "..."
# $data{'source'}{$srcpkg}{$version}{'build-depends|build-depends-indep|build-conflicts|build-conflicts-indep'}{$pkg} = <<|>>|<=|>=|==|none
#
# $data{'bin'}{$binpkg}{$version}

# $data{'suite'}{$suite}{'pkgs'}{$binpkg} = $version        # there can only be one version per suite
#
# $data{'people'}{$email}{'name'} = "..."
# $data{'people'}{$email}{'pkgs'}{$srcpkg}{$version} = 1

sub parse_version {
  my $d = shift;
  # TODO $d cleaning:
  # remove arch specifications:
  #print "DEBUG: PRE d=$d=\n";
  $d =~ s/\s*\[.*$//;
  $d =~ s/\s*\s<.*$//;
  #print "DEBUG: POST d=$d=\n";
  my $realdep = $d;
  my $realver = 1;
  my $realrel = "none";
  #print "DEBUG: analysing $d\n";
  if ($d =~ m/^(.*) \((.*)\)$/) {
    $realdep = $1;
    $foo = $2;
    if ($foo =~ m/^((<|=|>|>>|<=|>=|<<)(?![=<>]))\s*(.*)$/) {
      $realrel = $1;
      $realver = $3;
    } else {
      print "DEBUG cannot break up !$foo!\n";
    }
  }
  #print "DEBUG(bin): FINAL !$realdep!$realrel!$realver!\n";
  return($realdep, $realrel, $realver);
}

sub read_packages_file {
  # '@$$packages' interface name must match the one from the last line in 'pull-udd.pl'
  for my $pkgpt (@$$packages) {
    my ($pkg,$version,$memail,$mname,$suite,$desc,@deplist) = @$pkgpt;
    my %deps;
    # tricky way to merge keys and values into hash!
    @deps{@bindeps} = @deplist;

    $data{'people'}{$memail}{'name'} = $mname;
    $data{'suite'}{$suite}{'pkgs'}{$pkg} = $version;
    if (!defined($data{'bin'}{$pkg}{'uuid'})) {
      $data{'bin'}{$pkg}{'uuid'} = myuuid();
    }
    if (!defined($data{'bin'}{$pkg}{$version}{'uuid'})) {
      $data{'bin'}{$pkg}{$version}{'uuid'} = myuuid();
    }

    $data{'bin'}{$pkg}{$version}{'maintainer'} = $memail;
    $data{'bin'}{$pkg}{$version}{'description'} = $desc;
    for my $deps (@bindeps) {
      for my $dp (split(/,/, $deps{$deps})) {
        $dp =~ s/^\s*//;
        $dp =~ s/\s*$//;
        # alternative treatments:
        # ....{$deps}{<fulldepstring>}{$dep1}{<relation>} = <version;
        for my $d (split(/ \| /, $dp)) {
          my ($realdep, $realrel, $realver) = parse_version($d);
          # $dp is the same for all alternative dependencies
          $data{'bin'}{$pkg}{$version}{$deps}{$dp}{$realdep}{$realrel} = $realver;
        }
      }
    }
  }
}

sub read_sources_file {
  # '@$$sources' interface name must match the one from the last line in 'pull-udd.pl'
  for my $pkgpt (@$$sources) {
    my ($pkg,$version,$memail,$mname,$suite,$uploaders,$bin,$architecture,@deplist) = @$pkgpt;
    my %deps;
    # tricky way to merge keys and values into hash!
    @deps{@srcdeps} = @deplist;
    $data{'people'}{$memail}{'name'} = $mname;
    my @uploaders = split(/,/, $uploaders);
    $data{'source'}{$pkg}{$version}{'maintainer'} = $memail;
    # should we warn on reused with different names?
    # if (defined($data{'people'}{$memail}) && $data{'people'}{$memail}{'name'} ne $mname) {
    #   print STDERR "WARN: $memail has multiple names: $mname, $data{'people'}{$memail}{'name'}\n";
    # }
    $data{'people'}{$memail}{'name'} = $mname;
    for my $u (@uploaders) {
      $u =~ s/^\s*//;
      $u =~ s/\s*$//;
      my ($uname, $uemail) = ($u =~ m/(.*) <(.*)>/);
      $data{'source'}{$pkg}{$version}{'uploader'}{$uemail} = 1;
    }
    for my $b (split(/, /, $bin)) {
      $data{'source'}{$pkg}{$version}{'binary'}{$b} = 1;
    }
    for my $a (split(' ', $architecture)) {
      $data{'source'}{$pkg}{$version}{'arch'}{$a} = 1;
    }
    # do dependencies
    for my $deps (@srcdeps) {
      for my $dp (split(/,/, $deps{$deps})) {
        $dp =~ s/^\s*//;
        $dp =~ s/\s*$//;
        # alternative treatments:
        # ....{$deps}{<fulldepstring>}{$dep1}{<relation>} = <version;
        for my $d (split(/ \| /, $dp)) {
          my ($realdep, $realrel, $realver) = parse_version($d);
          # $dp is the same for all alternative dependencies
          $data{'source'}{$pkg}{$version}{$deps}{$dp}{$realdep}{$realrel} = $realver;
        }
      }
    }
  }
}


1;

# vim:set tabstop=2 shiftwidth=2 expandtab: #
