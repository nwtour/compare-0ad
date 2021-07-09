
use strict;
use Data::Dumper;
use XML::LibXML::Reader;
use File::Slurp qw(read_file);
use JSON qw(from_json);
use List::Util qw(uniq);
use Getopt::Long;
use File::Spec::Functions qw(catfile);

my $only_lang = "";
my $doc_dir = "docs";

GetOptions("docdir=s" => \$doc_dir, "lang=s" => \$only_lang);

sub translate {
	my ($string, $lang, $context) = @_;

	return $string if $lang eq 'en';

	my @lines;

	foreach my $cf (
		'public-gui-other.po',
		'public-gui-ingame.po',
		'public-templates-buildings.po',
		'public-civilizations.po',
		'public-simulation-technologies.po'
		) {
		my @cl = read_file("binaries/data/mods/public/l10n/$lang.$cf");
		push @lines, @cl;
	}
	my $i = 0;
	my $re = $string;
	$re =~ s/\+/\\\+/g;
	while(exists $lines[$i]) {

		if ($lines[$i] =~ /msgid "$re"/) {

			return $1 if ($lines[($i - 1)] =~ /$context/ || $lines[($i - 2)] =~ /$context/) && $lines[($i + 1)] =~ /msgstr "(.+)"/;
		}
		$i++;
	}
	warn "($lang) NOT FOUND $string\n";
	return $string;
}

sub get_xml_value {
	my ($filename, @list) = @_;
	
	my $reader = XML::LibXML::Reader->new(location => "binaries/data/mods/public/$filename")
		or die "cannot read $filename\n";

	$reader->preservePattern('/' . join('/', @list));
	$reader->finish;

	my ($node) = $reader->document->getElementsByTagName($list[-1]);

	return "" unless defined $node;
	return $node->textContent;
}

sub civbonuses {
	my ($value, $fraction, $building, $param, $lang, $description) = @_;

	return $value unless $value;

	#warn "Search $fraction, $building $param\n";
	foreach my $f (grep { -f $_ } glob("binaries/data/mods/public/simulation/data/technologies/civbonuses/*.json")) {
		$f = from_json(read_file($f));
		last if ! exists $f->{modifications};
		if (exists $f->{requirements} && exists $f->{requirements}{any}) {

			foreach my $i (0 .. 10) {
				last if ! exists $f->{requirements}{any}[$i];
				next if $f->{requirements}{any}[$i]{civ} ne $fraction;
				foreach my $k (0 .. 10) {
					last if ! exists $f->{modifications}[$k];
					next if $f->{modifications}[$k]{value} ne $param;
					if(exists $f->{modifications}[$k]{multiply}) {

						$value = int($value * $f->{modifications}[$k]{multiply});
						push @{$description}, translate($f->{genericName}, $lang, '_structures.json')
						. ' : ' . translate($f->{tooltip}, $lang, '_structures.json');
					}
				}
			}
		}
	}
	
	return $value;
}

sub line_end {
	return "<br>\n";
}

sub table_tab {
	return '</td><td>';
}

sub table_startline {
	return '<tr><td>';
}

sub table_endline {
	return "</td></tr>";
}

sub table_start {
	return '<table>';
}

sub table_end {
	return '</table>';
}

sub icon {
	my $name = shift;

	return "<img src='https://raw.githubusercontent.com/0ad/0ad/master/binaries/data/mods/public/art/textures/ui/session/portraits/structures/" .
		lc($name) . ".png' width='20' height='20'>";
}

sub h3 {
	return '<h3>';
}

sub h3_end {
	return '</h3>';
}

sub h2 {
	return '<h2>';
}

sub h2_end {
	return '</h2>';
}

my @languages = map { /l10n\/(.+)\.public-tutorials/; $1 } grep { -f $_ } glob("binaries/data/mods/public/l10n/*.public-tutorials.po");

push @languages, 'en';

my $fd;

open($fd, '>', catfile ($doc_dir, 'index.html'));

my $prev_letter = "a";

foreach my $lang (sort (@languages)) {

	next if $lang eq 'long';

	if (substr($lang, 0, 1) ne $prev_letter) {
		$prev_letter = substr($lang, 0, 1);
		print $fd line_end . line_end;
	}

	print $fd " | <a href='$lang.html'>$lang</a>";
}

close($fd);

foreach my $lang (sort (@languages)) {

	next if $only_lang && $lang ne $only_lang;

	open ($fd, '>', catfile ($doc_dir, "$lang.html"));

	print $fd h2 . '<a href="index.html">[index]</a>/' . $lang . '.html' . h2_end . line_end . line_end;

	my $popbonus = substr(translate("Population Bonus:", $lang, 'tooltips.js'), 0, -1);

	my %fraction;

	foreach my $f (grep { -f $_ } glob("binaries/data/mods/public/simulation/data/civs/*.json")) {

		$f = from_json(read_file($f));
		$fraction{ $f->{Code} } = translate($f->{Name}, $lang, $f->{Code} . '.json');
	}

	my $resources = {
		'Food'   => { seq => 2, name => translate('Food', $lang, 'food.json'), sym => '🥩' },
                'Wood'   => { seq => 3, name => translate('Wood', $lang, 'wood.json'), sym => '🪓' },
                'Metal'  => { seq => 4, name => translate('Metal', $lang, 'metal.json'),sym => '⛏️'  },
                'Stone'  => { seq => 5, name => translate('Stone', $lang, 'stone.json'),sym => '🧱' },
		'Time'   => { seq => 6, name => substr(translate("Remaining build time:", $lang, 'tooltips.js'), 0, -1), sym => '⌚' },
		'Health' => { seq => 1, name => translate('Health', $lang, 'tooltips.js'), sym => '❤️' },
		'Pop'    => { seq => 7, name => substr(translate("Population Bonus:", $lang, 'tooltips.js'), 0, -1), sym => '🧑‍🤝‍🧑' }
	};

	foreach my $r (sort { $resources->{$a}{seq} <=> $resources->{$b}{seq} } keys %$resources) {
		print $fd $resources->{$r}{name} . " = " . $resources->{$r}{sym} . ", ";
	}
	print $fd line_end . line_end;

	print $fd table_start;

	foreach my $template (
		'template_structure_civic_civil_centre.xml',
        	'template_structure_civic_house.xml',
                'template_structure_civic_temple.xml',
		'template_structure_economic_farmstead.xml',
		'template_structure_economic_market.xml',
		'template_structure_economic_storehouse.xml',
		'template_structure_military_barracks.xml',
		'template_structure_military_dock.xml',
		'template_structure_military_fortress.xml',
		'template_structure_resource_corral.xml'
		) {

		my $en_name = get_xml_value("simulation/templates/$template", 'Entity', 'Identity', 'GenericName');

		my $en_filename = $template;
		$en_filename =~ s/^template_structure_([a-z]+)_(.+)\.xml/$2/;

		# Workarround
		$en_filename = 'civic_centre' if $en_filename eq 'civil_centre';

		print $fd table_startline .
			translate('Civilization', $lang, 'DiplomacyDialog.xml') .
			table_tab .
			h3 . icon($en_filename) . translate($en_name, $lang, $template) . h3_end .
			table_endline;

		foreach my $f (sort keys %fraction) {
			print $fd table_startline . $fraction{$f} . table_tab;

			my ($v, @descr);
			$v = get_xml_value("simulation/templates/$template", 'Entity', 'Health', 'Max');
			$v = civbonuses($v, $f, $en_name, 'Health/Max', $lang, \@descr);
			print $fd ($v ? $v . $resources->{Health}{sym} . " " : "");
			$v = get_xml_value("simulation/templates/$template", 'Entity', 'Cost', 'Resources', 'food');
			print $fd ($v ? $v . $resources->{Food}{sym} . " " : "");
			$v = get_xml_value("simulation/templates/$template", 'Entity', 'Cost', 'Resources', 'wood');
			$v = civbonuses($v, $f, $en_name, 'Cost/Resources/wood', $lang, \@descr);
			print $fd ($v ? $v . $resources->{Wood}{sym} . " " : "");
			$v = get_xml_value("simulation/templates/$template", 'Entity', 'Cost', 'Resources', 'stone');
			print $fd ($v ? $v . $resources->{Stone}{sym} . " " : "");
			$v = get_xml_value("simulation/templates/$template", 'Entity', 'Cost', 'Resources', 'metal');
			print $fd ($v ? $v . $resources->{Metal}{sym} . " " : "");
			$v = get_xml_value("simulation/templates/$template", 'Entity', 'Cost', 'BuildTime');
			$v = civbonuses($v, $f, $en_name, 'Cost/BuildTime', $lang, \@descr);
			print $fd ($v ? $v . $resources->{Time}{sym} . " " : "");
			$v = get_xml_value("simulation/templates/$template", 'Entity', 'Population', 'Bonus');
			print $fd ($v ? $v . $resources->{Pop}{sym} . " " : "");
			print $fd table_tab . join(' ', uniq(@descr)) if scalar(@descr);
			print $fd line_end;
		}
	}
	print $fd line_end;
	print $fd table_end;
	close($fd);
}
