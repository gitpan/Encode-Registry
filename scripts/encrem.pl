use XML::Smart;
use Getopt::Std;
use Text::ParseWords;
use File::Spec;

$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

getopts('hqr:o:');

%keyattrs = (
    encoding => 'name',
    encodingMapping => 'name',
    encodingProperty => 'name',
    alias => 'name',
    mapping => 'name',
    specProperty => 'name',
    mappingProperty => 'name',
    font => 'name',
    platform => 'name');

%commands = (
    'add-alias' => \&add_alias,
    'add-encoding' => \&add_encoding,
    'add-enc' => \&add_encoding,
    'add-implementation' => \&add_impl,
    'add-impl' => \&add_impl,
    'add-font' => \&add_font,
    'add-font-mapping', => \&add_font_mapping,
    'add-font-map', => \&add_font_mapping,
    'add-mapping' => \&add_mapping,
    'add-map' => \&add_mapping,
    'create' => \&create,
    'del-alias' => \&del_alias,
    'del-encoding' => \&del_encoding,
    'del-enc' => \&del_encoding,
    'del-font' => \&del_font,
    'del-font-mapping', => \&del_font_mapping,
    'del-font-map', => \&del_font_mapping,
    'del-implementation' => \&del_impl,
    'del-impl' => \&del_impl,
    'del-mapping' => \&del_mapping,
    'del-map' => \&del_mapping,
    'exit' => \&finish,
    'help' => \&help,
    'list-encoding' => \&list_encoding,
    'list-enc' => \&list_encoding,
    'list-font' => \&list_font,
    'list-mapping' => \&list_mapping,
    'list-map' => \&list_mapping,
    'quit' => \&quit,
    'register' => \&register,
    );

if ($opt_h)
{
    die <<'EOT'
    encrem [-q] [-r regfile] [-o outfile] [command [options] values]
Edits an encoding registry file according to the command given

Type "encrem help" for a list of commands, or "encrem help command" for help on
a particular command. Typing "encrem" on its own puts you into a commandline
mode where multiple commands may be given in one session before saving files,
etc.

  -q            Quiet: Don't output commentary
  -r regfile    Use this file if no registry file is found
  -o outfile    Output everything to this file
EOT
}

#' keep editors happy

require Encode::Registry;
$regfile = Encode::Registry->find_registry;
$opt_r = $regfile || $opt_r;

if ($opt_r && -r $opt_r)
{
    $xml = XML::Smart->new($opt_r);
    $ref = $xml->{'mappingRegistry'};
}
else
{
    create();
}

$outfile = $opt_o;
$outfile = $opt_r unless ($outfile);
$changed = ("$outfile" eq "$opt_o");

unless ($opt_q)
{
    print "Input file: $opt_r\n" if ($opt_r);
    print "Output file: $outfile\n" if ($outfile);
}

$command = shift;
if ($command)
{
    if (defined $commands{$command})
    {
        if (&{$commands{$command}}($ref) || $changed)
        { save($xml, $outfile); }
    }
}
else
{
    $exit = 0;
    while (!$exit)
    {
        print "encrem: ";
        $instr = <STDIN>;
        @ARGV = shellwords($instr);
        $command = shift;
        if (defined $commands{$command})
        { $changed |= &{$commands{$command}}($ref); }
        else
        { print "Unknown command $command\n"; }
    }
    save($xml, $outfile) if ($changed);
}

sub save
{
    my ($xml, $outfile) = @_;
    my ($ans);
    
    unless ($outfile || $opt_q)
    {
        print "No output file specified. Please specify or blank to quit:";
        $outfile = <STDIN>;
        $outfile =~ s/^\s*(.*?)\s*$/$1/o;
    }
    $xml->save($outfile, nometagen => 1) if ($outfile);
}
    
sub help
{
    my ($ref, $help) = @_;
    my ($name) = shift @ARGV;
    my ($key, %revcommands);
    
    return &{$commands{$name}}($ref, 1) if (!$help && defined $commands{$name});
    print "Type: help command for help on a particular command:\n    ";
    foreach $key (keys %commands)
    { $revcommands{"$commands{$key}"} = $key 
        if (!defined $revcommands{"$commands{$key}"} && 
            length($revcommands{"$commands{$key}"}) < length($key)); }
    print join ("\n    ", sort values %revcommands);
    print "\n";
    return 0;
}


sub finish
{
    my ($ref, $help) = @_;
    
    if ($help)
    {
        print <<'EOT';
exit

Save file and exit
EOT
        return 0;
    }
    $exit = 1;
    return 0;
}


sub quit
{
    my ($ref, $help) = @_;
    
    if ($help)
    {
        print <<'EOT';
quit

Don't save file and exit
EOT
#' to keep editors happy

        return 0;
    }
    
    $changed = 0;
    $exit = 1;
    return 0;
}


sub create
{
    my ($dump, $help) = @_;
    
    if ($help)
    {
        print <<'EOT';
create

Create a new empty XML Registry file to save data into
EOT
        return 0;
    }
    
    $xml = XML::Smart->new(<<'EOT');
<?xml version="1.0"?>
<mappingRegistry>
    <encodings/>
    <mappings/>
    <fonts/>
    <implementations>
        <platform name="Encode::Registry">
            <implement type="cp" use="Encode::WinCP" priority="5"/>
            <implement type="SIL.tec" use="Encode::TECkit" priority="4"/>
            <implement type="SIL.utr22c" use="Encode::UTR22" priority="-2"/>
        </platform>
    </implementations>
</mappingRegistry>
EOT
    $ref = $xml->{'mappingRegistry'};
    return 1;
}


sub register
{
    my ($ref, $help) = @_;
    my ($instr, $ok);
    local($opt_n, $opt_q);
    
    getopts('q:');
    
    if ($help)
    {
        print <<'EOT';
register [-q ans]

Registers current outfile in the Windows registry for other applications to
find this file as the encoding registry file to use.

  -q ans    Don't prompt if there is a registry file already registered
            Provides answer (yes or no)
EOT
#' to keep editors happy
        return 0;
    }
    
    if ($^O eq 'MSWin32')
    {
        require Win32::TieRegistry;
        Win32::TieRegistry->import(Delimiter => '/');

        $ok = 1;
        $Registry->{"LMachine/SOFTWARE/SIL/"} = {'EncodingConverterRepository/' => {}} unless ($Registry->{"LMachine/SOFTWARE/SIL/EncodingConverterRepository/"});
        $file = $Registry->{"LMachine/SOFTWARE/SIL/EncodingConverterRepository//Registry"};
        if ($file)
        {
            if ($opt_q)
            { $instr = $opt_q; }
            else
            {
                print "Current value = $file. Are you sure you want to change? [y/N] ";
                $instr = <STDIN>;
                chomp;
            }
            unless ($instr =~ m/^y(?:es|$)/oi)
            { $ok = 0; }
        }
        $Registry->{"LMachine/SOFTWARE/SIL/EncodingConverterRepository//Registry"} = File::Spec->rel2abs($outfile) if ($ok);
    }
    return 0;
}    


sub add_encoding
{
    my ($ref, $help) = @_;
    local($opt_m, $opt_t, $opt_u, $res);
    
    getopts('m:t:u:');
    
    my ($name) = shift @ARGV;
    if ($help || !$name)
    {
        print <<'EOT';
encrem add-encoding [-m mapping] [-t type] [-u unicode] encoding_name [file]

Adds an encoding to the registry of the given encoding_name. Fails if there is
an encoding of that name already present. Also adds a corresponding unicode
encoding either of "$name Unicode" or given by -u. Calculates a mapping name
from the mapping file, or as "$name <> Unicode" or from -m. The type of the
file is calculated from the file itself or from the -t option.
EOT
        return 0;
    }
    
    my ($spec) = shift @ARGV;
    my ($file) = File::Spec->rel2abs($spec);
    $res = 1;
    $res = error("Encoding $name already defined, just adding mapping") if ($ref->{'encodings'}{'encoding'}('name', 'eq', $name){'name'});
    $opt_u = "$name Unicode" unless ($opt_u);
    ($type, $mname) = parse_impl($spec);
    $opt_m = $mname unless ($opt_m);
    $opt_m = "$name <> Unicode" unless ($opt_m);
    $opt_t = $type unless ($opt_t);
    
    push (@{$ref->{'encodings'}{'encoding'}}, {name => $name, defineMapping => {becomes => $opt_u, name => $opt_m}});
    push (@{$ref->{'encodings'}{'encoding'}}, {name => $opt_u, isUnicode => 1, defineMapping => {
                                                    becomes => $name, reverse => 'true', name => $opt_m}})
            unless ($ref->{'encodings'}{'encoding'}('name', 'eq', $opt_u){'name'});
    if ($spec)
    {
        push (@{$ref->{'mappings'}{'mapping'}}, {'name' => $opt_m}) 
                unless ($ref->{'mappings'}{'mapping'}('name', 'eq', $opt_m){'name'});
        my ($enc) = $ref->{'mappings'}{'mapping'}('name', 'eq', $opt_m);
        return error("Mapping $opt_m already specified by $file") 
                if ($enc->{'specs'}{'spec'}('path', 'eq', $file){'path'});
        if (defined $enc->{'specs'}->null())
        { $enc->{'specs'} = {'spec' => [{'path' => $file, 'type' => $opt_t}]}; }
        else
        { push (@{$enc->{'specs'}{'spec'}}, {'path' => $file, 'type' => $opt_t}); }
        return 1;
    }
    return $res;
}


sub del_encoding
{
    my ($ref, $help) = @_;
    my ($enc, $i, $res);
    my ($name) = shift @ARGV;
    
    if (!$name || $help)
    {
        print <<'EOT';
del-encoding name

Deletes the encoding entry of the given name. No other encodings or mappings
are deleted.
EOT
        return 0;
    }
    
    for ($i = 0; $i < scalar @{$ref->{'encodings'}{'encoding'}}; $i++)
    {
        if ($ref->{'encodings'}{'encoding'}[$i]{'name'} eq $name)
        {
            $res = 1;
            splice(@{$ref->{'encodings'}{'encoding'}}, $i, 1);
        }
    }
    unless ($res)
    {
        return error("Unable to find encoding $name");
    }
    return $res;
}


sub list_encoding
{
    my ($ref) = @_;
    local($opt_n);
    
    my ($k, $e);
    getopts('n');
    my ($name) = shift @ARGV;
    
    foreach $e (@{$ref->{'encodings'}{'encoding'}})
    {
        if ((!$opt_n && $e->{'name'} =~ m/$name/i) || ($opt_n && $e->{'name'} !~ m/$name/i))
        {
            if ($e->{'isUnicode'})
            {
                $range = ref($e->{'rangeCoverage'}[0]) ? $e->{'rangeCoverage'}[0]{'cpg'} : $e->{'rangeCoverage'}[0];
                $range =~ s/^\s*(.*?)\s*$/$1/o;
                print <<"EOT";
Encoding: $e->{'name'}
    Defined Mapping: $e->{'defineMapping'}{'name'}
    Byte encoding: $e->{'defineMapping'}{'becomes'}
    Range covered: $range
EOT
            }
            else
            {
                print <<"EOT";
Encoding: $e->{'name'}
    Defined Mapping: $e->{'defineMapping'}{'name'}
    Unicode encoding: $e->{'defineMapping'}{'becomes'}
EOT
            }
            print "    Aliases: " . join (', ', sort $e->{aliases}{alias}{'name'}('<@')) . "\n";
        }
    }
    return 0;
}


sub add_alias
{
    my ($ref, $help) = @_;
    my ($name) = shift @ARGV;
    my ($base) = shift @ARGV;
    my ($enc);
    
    if ($help || !$base)
    {
        print <<'EOT';
add-alias alias_name encoding

Adds an alias to a given encoding
EOT
        return 0;
    }
    
    foreach $enc (@{$ref->{'encodings'}{'encoding'}})
    {
        if ($enc->{'aliases'}{'alias'}('name', 'eq', $name) && $enc->{'name'} ne $base)
        { return error("Alias $name already declared for $enc->{'name'}"); }
    }
    
    $enc = $ref->{'encodings'}{'encoding'}('name', 'eq', $base);
    unless ($enc->null())
    {
        unless ($enc->{'aliases'}{'alias'}('name', 'eq', $name){'name'})
        {
            push(@{$enc->{'aliases'}{'alias'}}, {'name' => $name});
            return 1;
        }
        else
        { return error("Alias $name for encoding $base already exists"); }
    }
    else
    { return error("No encoding of name $base exists"); }
}

sub del_alias
{
    my ($ref, $help) = @_;
    my ($name) = shift @ARGV;
    my ($enc, $res, $i);
    
    if ($help || !$name)
    {
        print <<'EOT';
del-alias alias_name

deletes the given encoding alias
EOT
        return 0;
    }
    
    foreach $enc (@{$ref->{'encodings'}{'encoding'}})
    {
        next unless ($enc->{'aliases'});
        for ($i = 0; $i < scalar @{$enc->{'aliases'}{'alias'}}; $i++)
        {
            if ($enc->{'aliases'}{'alias'}[$i]{'name'} eq $name)
            { 
                splice(@{$enc->{'aliases'}{'alias'}}, $i, 1);
                $res = 1;
            }
        }
    }
    unless ($res)
    {
        return error("Unable to find alias $name");
    }
    return $res;
}

   
sub add_impl
{
    my ($ref, $help) = @_;
    my ($plat, $impl);
    local($opt_p, $opt_q, $opt_r);
    
    getopts('p:q:r:');
    
    my ($type) = shift @ARGV;
    my ($use) = shift @ARGV;
    
    if ($help || !$use)
    {
        print <<'EOT';
add-implementation [-p platform] [-q ans] [-r priority] type use

Add implementation details for a particular implementation identifier.

    -p platform     platform we are describing [Encode::Registry]
    -q ans          Quiet. Don't query if an implementation already exists
                    Provides the answer to the question (yes or no)
    -r priority     priority of use of this implementation type [0]
EOT
#' to keep editors happy
        return 0;
    }
    
    $opt_p ||= 'Encode::Registry';
    
    unless ($plat = $ref->{'implementations'}{'platform'}('name', 'eq', $opt_p){'name'})
    {
        push(@{$ref->{'implementations'}{'platform'}}, {'name' => $opt_p});
        $plat = $ref->{'implementations'}{'platform'}('name', 'eq', $opt_p);
    }
    if ($impl = $plat->{'implement'}('type', 'eq', $type))
    {
        if ($impl->{'use'} ne $use)
        {
            if ($opt_q)
            { $ans = $opt_q; }
            else
            {
                print "An implementation exists for $type using $use, do you want to change it [y/N]? ";
                $ans = <STDIN>;
            }
            if ($ans !~ m/^y(?:es|$)/oi)
            { return 0; }
            else
            { $impl->{'use'} = $use; }
        }
        if (defined $opt_r)
        { $impl->{'priority'} = $opt_r; }
    }
    else
    { push (@{$plat->{'implement'}{'type'}}, {'type' => $type, 'use' => $use, 'priority' => $opt_r}); }
    return 1;
}


sub del_impl
{
    my ($ref, $help) = @_;
    my ($res, $i, $imp);
    local($opt_p);
    
    getopts('p:');
    my ($type) = shift @ARGV;
    
    if (!$type || $help)
    {
        print <<'EOT';
del-implementation [-p platform] type

Deletes an implementation specification of the given type in the given
platform.

    -p platform     Platform to delete form [Encode::Registry]
EOT
        return 0;
    }
    
    $opt_p ||= 'Encode::Registry';
    my ($imp) = $ref->{'implementations'}{'platform'}('name', 'eq', $opt_p);
    
    for ($i = 0; $i < scalar @{$imp->{'implements'}}; $i++)
    {
        if ($imp->{'implements'}[$i]{'type'} eq $type)
        {
            $res = 1;
            splice (@{$imp->{'implements'}}, $i, 1);
        }
    }
    unless ($res)
    {
        return error("Unable to find implementation of type $type in platform $opt_p");
    }
    return $res;
}


sub add_mapping
{
    my ($ref, $help) = @_;
    local ($opt_q, $opt_t);
    getopts('q:t:');
    
    my ($name) = shift @ARGV;
    my ($spec) = shift @ARGV;
    my ($map, $res, $file);
    
    if ($help || !$name)
    {
        print <<'EOT';
add-mapping [-q ans] [-t type] name [spec_file]

Adds a mapping of the given name. In addition a specification file with
optionally specified type my be included. If the mapping already exists, the
specification is added to it.
EOT
        return 0;
    }
    
    $opt_t = parse_impl($spec) if ($spec && !defined $opt_t);
    
    unless ($map = $ref->{'mappings'}{'mapping'}('name', 'eq', $name){'name'})
    {
        push(@{$ref->{'mappings'}{'mapping'}}, {'name' => $name});
        $map = $ref->{'mappings'}{'mapping'}('name', 'eq', $name);
        $res = 1;
    }
    
    if ($spec)
    {
        $file = File::Spec->rel2abs($spec);
        foreach $s (@{$map->{'specs'}{'spec'}})
        {
            if (File::Spec->rel2abs($s->{'path'}) eq $file)
            {
                if ($opt_t eq $s->{'type'})
                {
                    error("Specification $spec already in mapping $name") unless ($opt_q);
                    return $res;
                }
                elsif ($opt_q)
                { $ans = $opt_q; }
                else
                {
                    print "Specification $spec already exists in mapping $name. But it has type $type.\n";
                    print "Do you want to change the type of the specification to $opt_t? [y/N] ";
                    $ans = <STDIN>
                }
                if ($ans =~ m/^y(?:es|$)/oi)
                { 
                    $s->{'type'} = $opt_t;
                    return 1;
                }
                else
                { return $res; }
            }
        }
        push (@{$map->{'specs'}{'spec'}}, {'path' => $file, 'type' => $opt_t});
        return 1;
    }
}


sub del_mapping
{
    my ($ref, $help) = @_;
    my ($name) = shift @ARGV;
    my ($i);
    
    if ($help || !$name)
    {
        print <<'EOT';
del-mapping name

Deletes the given mapping without deleting references to it.
EOT
        return 0;
    }
    
    for ($i = 0; $i < scalar @{$ref->{'mappings'}{'mapping'}}; $i++)
    {
        if ($ref->{'mappings'}{'mapping'}[$i]{'name'} eq $name)
        {
            splice(@{$ref->{'mappings'}{'mapping'}}, $i, 1);
            $res = 1;
        }
    }
    unless ($res)
    {
        return error("No mapping of name $name found");
    }
    return $res;
}


sub list_mapping
{
    my ($ref, $help) = @_;
    local($opt_n);
    
    getopts('n');
    my ($name) = shift @ARGV;
    my ($k, $e);
    if ($help || !$name)
    {
	print <<'EOT';
list-mapping name

Lists information about a mapping whose name matches the regular
expression that is name.
EOT
        return 0;
    }
    
    foreach $e (@{$ref->{'mappings'}{'mapping'}})
    {
        if ((!$opt_n && $e->{'name'} =~ m/$name/i) || ($opt_n && $e->{'name'} !~ m/$name/i))
        {
            print "Mapping: $e->{'name'}\n";
            foreach $s (@{$e->{'specs'}{'spec'}})
            {
                print "    Implemented by: $s->{'path'} as $s->{'type'}\n";
            }
        }
    }
    return 0;
}


sub add_font
{
    my ($ref, $help) = @_;
    my ($res, $font, $enc, $unique, $ans);
    local ($opt_c, $opt_e, $opt_q, $opt_u);
    getopts('c:e:q:u');

    my ($name) = shift @ARGV;

    if ($help || !$name)
    {
	print <<'EOT';
add-font [-c cp] [-e encoding] [-u] <font name>

Adds a font (if not present) and an encoding associated with that font.

  -c codepage    system codepage of font
  -e encoding    name of existing encoding to associate with the font
  -q ans         don't query, default answer to ans
  -u             The default encoding associated with a font. This may
                 only be set on one encoding per font.
EOT
#' for editors
        return 0;
    }

    $font = $ref->{'fonts'}{'font'}('name', 'eq', $name);
    if ($font->null())
    {
        push(@{$ref->{'fonts'}{'font'}}, {'name' => $name});
        $font = $ref->{'fonts'}{'font'}('name', 'eq', $name);
        $res = 1;
    }

    if ($opt_e)
    {
    	$enc = $font->{'fontEncodings'}{'fontEncoding'}('name', 'eq', $opt_e);
    	if ($enc->null())
    	{
    	    push(@{$font->{'fontEncodings'}{'fontEncoding'}}, {'name' => $opt_e});
    	    $enc = $font->{'fontEncodings'}{'fontEncoding'}('name', 'eq', $name);
    	    $res = 1;
    	}

    	if ($opt_u)
    	{
    	    $unique = $font->{'fontEncodings'}{'fontEncoding'}('unique', 'eq', 'true');
    	    unless ($unique->null())
    	    {
        		if ($unique->{'name'} ne $opt_e)
        		{
        		    if ($opt_q)
        		    { $ans = $opt_q; }
        		    else
        		    {
            			print "font $name encoding $unique->{'name'} is set to unique,\ndo you want to move it to $opt_e [y/N]?";
            			$ans = <STDIN>;
        		    }
        		    if ($ans !~ m/^y(?:es|$ )/oix)
        		    {
            			delete $unique->{'unique'};
            			$enc->{'unique'} = 'true';
            			$res = 1;
        		    }
        		}
            }
    	    else
    	    { 
        		$enc->{'unique'} = 'true';
        		$res = 1;
    	    }
    	}
    }
    return $res;
}


sub add_font_mapping
{
    my ($ref, $help) = @_;
    my ($res, $ans, $map, $font);
    local ($opt_a, $opt_m, $opt_q);
    getopts('a:m:q:');

    my ($name) = shift @ARGV;

    if ($help || !$name || !$opt_m)
    {
    	print <<'EOT';
add-font-mapping [-a font] -m mapping [-q ans] font

Adds a font mapping relationship to a mapping giving an optional associated
font across the mapping.

  -a font      Associated font
  -m mapping   Mapping font mapping is associated with
  -q ans       Don't query, default answer to ans
EOT
#' for editors
        return 0;
    }

    $map = $ref->{'mappings'}{'mapping'}('name', 'eq', $opt_m);
    if ($map->null())
    {
    	error("Mapping $opt_m does not exist");
    	return $res;
    }

    $font = $map->{'fontMappings'}{'fontMapping'}('name', 'eq', $name);
    if ($font->null())
    {
    	push(@{$map->{'fontMappings'}{'fontMapping'}}, {'name' => $name});
    	$font = $map->{'fontMappings'}{'fontMapping'}('name', 'eq', $name);
    	$font->{'assocFont'} = $opt_a if ($opt_a);
    	$res = 1;
    }
    elsif ($opt_a && $font->{'assocFont'} && $font->{'assocFont'} ne $opt_a)
    {
    	if ($opt_q)
    	{ $ans = $opt_q; }
    	else
    	{
    	    print "Font $name in mapping $opt_m has an existing associated font $font->{'assocFont'}\nDo you want me to change it [y/N]?";
    	    $ans = <STDIN>;
    	}
    	if ($ans !~ m/^y(?:es|$ )/oix)
    	{
    	    $font->{'assocFont'} = $opt_a;
    	    $res = 1;
    	}
    }
    elsif ($opt_a)
    {	
    	$font->{'assocFont'} = $opt_a;
    	$res = 1;
    }
    return $res;
}


sub list_font
{
    my ($ref, $help) = @_;
    my ($map, $font, %res);
    my ($name) = shift @ARGV;

    if ($help || !$name)
    {
    	print <<'EOT';
list-font name

Lists information about a font and the mappings that interact with it
where the name of the font matches that given by name which is a regular
expression.
EOT
        return 0;
    }

    foreach $font ($ref->{'fonts'}{'font'}('name', '=~', $name))
    {
	    my ($nm) = $font->{'name'};
    	foreach $enc (@{$font->{'fontEncodings'}{'fontEncoding'}})
    	{
    	    $res{$nm}{'encs'} .= "  $enc->{'name'}";
    	    $res{$nm}{'encs'} .= "*" if ($enc->{'unique'} eq 'true');
    	}
    }

    foreach $map (@{$ref->{'mappings'}{'mapping'}})
    {
    	foreach $font ($map->{'fontMappings'}{'fontMapping'}('name', '=~', $name))
    	{
    	    $nm = $font->{'name'};
    	    $res{$nm}{'map'} .= "  $map->{'name'}";
    	    $res{$nm}{'map'} .= "->$font->{'assocFont'}" if ($font->{'assocFont'});
    	}
    }

    foreach $font (sort keys %res)
    {
    	print "Font: $font\n  Encodings:$res{$font}{'encs'}\n";
    	print "  Mappings:$res{$font}{'map'}\n";
    }
    return 0;
}


sub del_font
{
    my ($ref, $help) = @_;
    my ($name) = shift @ARGV;
    my ($i, $res, $map);

    if ($help || !$name)
    {
	    print <<'EOT';
del-font name

Deletes all references to the font whose name is identical to the given name
EOT
        return 0;
    }

    for ($i = 0; $i < scalar @{$ref->{'fonts'}{'font'}}; $i++)
    {
        if ($ref->{'fonts'}{'font'}[$i]{'name'} eq $name)
        {
            splice(@{$ref->{'fonts'}{'font'}}, $i, 1);
            $res = 1;
        }
    }

    foreach $map (@{$ref->{'mappings'}{'mapping'}})
    {
    	for ($i = 0; $i < scalar @{$map->{'fontMappings'}{'fontMapping'}}; $i++)
    	{
    	    if ($ref->{'fontMappings'}{'fontMapping'}[$i]{'name'} eq $name)
    	    {
    		splice(@{$ref->{'fontMappings'}{'fontMapping'}}, $i, 1);
    		$res = 1;
    	    }
    	}
    }
	
    return $res;
}


sub del_font_mapping
{
    my ($ref, $help) = @_;
    my ($i, $res, $map);
    local ($opt_m);

    getopts('m:');
    my ($name) = shift @ARGV;

    if ($help || !$name || !$opt_m)
    {
    	print <<'EOT';
del-font-mapping -m mapping name

Deletes a fontMapping in the given mapping of the given name
EOT
        return 0;
    }

    if ($map = $ref->{'mappings'}{'mapping'}('name', 'eq', $opt_m))
    {
    	for ($i = 0; $i < scalar @{$map->{'fontMappings'}{'fontMapping'}}; $i++)
    	{
    	    if ($ref->{'fontMappings'}{'fontMapping'}[$i]{'name'} eq $name)
    	    {
    		splice(@{$ref->{'fontMappings'}{'fontMapping'}}, $i, 1);
    		$res = 1;
    	    }
    	}
    }
	
    return $res;
}


sub parse_impl
{
    my ($fname) = @_;
    my ($mname, $ext) = $fname =~ m{/?(.*?)\.(.*?)$}o;
    my ($type);
    
    if (lc($ext) eq 'tec')
    {
        $type = 'SIL.tec';
    }
    elsif (lc($ext) eq 'xml')
    {
        $type = 'SIL.utr22';
    }
    elsif ($fname =~ /^[0-9]+$/o)
    {
        $type = 'cp';
        $mname = $fname;
    }
    ($type, $mname);
}
            
sub error
{
    print STDERR @_;
    print STDERR "\n";
    return undef;
}
