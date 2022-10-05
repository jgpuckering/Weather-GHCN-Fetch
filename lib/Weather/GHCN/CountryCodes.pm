# CountryCodes.pm - map country codes to country names.

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

Weather::GHCN::CountryCodes - convert between various country codes

=head1 SYNOPSIS

  use Weather::GHCN::CountryCodes qw(:all);


=head1 DESCRIPTION

The B<CountryCodes> module provides functions to search a table of country
codes and country names using various search criteria.  It can also do a
direct lookup of a country entry using the 2-character GEC (formerly FIPS)
code.

The source for the mapping table is taken from the CIA World Factbook.  See
https://www.cia.gov/library/publications/the-world-factbook/appendix/appendix-d.html

The module is primarily for use by modules Weather::GHCN::Options, and 
Weather::GHCN::StationTable.

=cut

## no critic [ValuesAndExpressions::ProhibitVersionStrings]
## no critic [TestingAndDebugging::RequireUseWarnings]
## no critic [ProhibitSubroutinePrototypes]

use v5.18;  # minimum for Object::Pad

use feature 'signatures';
no warnings 'experimental::signatures';


package Weather::GHCN::CountryCodes;

our $VERSION = 'v0.0.000';

use Carp        qw(carp croak cluck confess);
use English     qw(-no_match_vars);
use Const::Fast;

use Exporter;
use parent 'Exporter';

# Items to export into callers namespace by default.
## no critic [Modules::ProhibitAutomaticExportation]
our @EXPORT = ( qw/ get_country_by_gec search_country  / );


my %Country;

# Preloaded methods go here.

# Constants

const my $EMPTY  => q();    # empty string
const my $SPACE  => q( );   # space character
const my $TAB    => qq(\t); # tab character
const my $TRUE   => 1;      # perl's usual TRUE
const my $FALSE  => not $TRUE; # a dual-var consisting of '' and 0


#############################################################################

# Load the %Country hash during the UNITCHECK phase, before any of the
# regular runtime code needs it.

UNITCHECK {
    my @lines = split m{ \n }xms, country_table();

    foreach my $line (@lines) {
        my ($entity, $gec, $iso2, $iso3, $isonum, $nato, $internet, $comment) = split m{ [|] }xms, $line;

        # skip table entries with no GEC
        next if $gec eq q(-);

        # check for duplicates, though there shouldn't be any
        croak "*W* country $entity with GEC $gec already exists"
            if $Country{$gec};

        $Country{$gec} = {
            'name'      => $entity,
            'gec'       => $gec,
            'iso2'      => $iso2,
            'iso3'      => $iso3,
            'isonum'    => $isonum,
            'nato'      => $nato,
            'internet'  => $internet,
            'comment'   => $comment
        };
    }
}

#############################################################################

=head1 FUNCTIONS

=head2 get_country_by_gec($code)

For a given GEC (FIPS) country code, return a hash containing the country
name and other country codes.  Returns empty if the code was not found.

=cut

sub get_country_by_gec ($code) {
    # uncoverable condition right
    return $Country{$code} // $EMPTY;
}

=head2 search_country( $search [, $type] )

Search the country table and return the entries which match the
search criteria.  The optional $type argument allows you to designate
which field the search criteria is to be matched against, as follows:

    name      does an unanchored pattern match on the country name
    gec       matches the GEC (formerly FIPS) country code
    iso2      matches the ISO 3166 2-character country code
    iso3      matches the ISO 3166 3-character country code
    isonum    matches the ISO 3166 country numeric code
    nato      matches the STANAG 1059 country code used by NATO
    internet  matches the internet country code (such as .ca)

If the search criteria is only two-characters long, then the type
defaults to gec.  To match a name, the search criteria must be longer
than three characters, otherwise you'll get results from matches against
gec or iso3.

In list context, all matches are returned.  In scalar context,
only the first match is returned.  Undef is returned if there
are no matches.

=cut

sub search_country ($search_value, $field) {
    my $search_key;

    ## no critic [ValuesAndExpressions::ProhibitMagicNumbers]
    ## no critic [ControlStructures::ProhibitCascadingIfElse]

    if ( defined $field ) {
        if ( $field !~ m{ \A (?: gec | iso2 | iso3 | isonum | nato | internet | name) \Z }xmsi) {
            croak 'invalid search field name';
        }
        $search_key = lc $field;
    } else {
        if ( $search_value =~ m{ \A \d+ \Z }xms ) {
            $search_key = 'isonum';
        }
        elsif ( $search_value =~ m{ \A [.][[:lower:]][[:lower:]] \Z }xmsi ) {
            $search_key = 'internet';
        }
        elsif ( length $search_value == 2 ) {
            $search_key = 'gec';
        }
        elsif ( length $search_value == 3 ) {
            $search_key = 'iso3';
        }
        # can't distinguish between iso3 and nato so this branch
        # would be unreachable -- removed for better test coverage
        # elsif ( length $search_value == 3 ) {
            # $search_key = 'nato';
        # }
        else {
            $search_key = 'name';
        }
    }

    my @results;
    foreach my $href (
        sort { $a->{$search_key} cmp $b->{$search_key} }
        values %Country )
    {
        my $v = lc $href->{$search_key};

        if ($search_key eq 'name') {
            ## no critic [RequireDotMatchAnything]
            ## no critic [RequireExtendedFormatting]
            ## no critic [RequireLineBoundaryMatching]
            push @results, $href if $v =~ m{$search_value}i;
        } else {
            push @results, $href if $v eq lc $search_value
        }
    }

    return @results;
}

=head2 country_table

Returns the country table.

=cut

sub country_table {
    my () = @_;

    #entity|gec|iso2|iso3|isonum|nato|internet|comment

    return <<'_TABLE_';
Afghanistan|AF|AF|AFG|4|AFG|.af|
Akrotiri|AX|-|-|-|-|-|
Albania|AL|AL|ALB|8|ALB|.al|
Algeria|AG|DZ|DZA|12|DZA|.dz|
American Samoa|AQ|AS|ASM|16|ASM|.as|
Andorra|AN|AD|AND|20|AND|.ad|
Angola|AO|AO|AGO|24|AGO|.ao|
Anguilla|AV|AI|AIA|660|AIA|.ai|
Antarctica|AY|AQ|ATA|10|ATA|.aq|ISO defines as the territory south of 60 degrees south latitude
Antigua and Barbuda|AC|AG|ATG|28|ATG|.ag|
Argentina|AR|AR|ARG|32|ARG|.ar|
Armenia|AM|AM|ARM|51|ARM|.am|
Aruba|AA|AW|ABW|533|ABW|.aw|
Ashmore and Cartier Islands|AT|-|-|-|AUS|-|ISO includes with Australia
Australia|AS|AU|AUS|36|AUS|.au|ISO includes Ashmore and Cartier Islands, Coral Sea Islands
Austria|AU|AT|AUT|40|AUT|.at|
Azerbaijan|AJ|AZ|AZE|31|AZE|.az|
Bahamas, The|BF|BS|BHS|44|BHS|.bs|
Bahrain|BA|BH|BHR|48|BHR|.bh|
Baker Island|FQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Bangladesh|BG|BD|BGD|50|BGD|.bd|
Barbados|BB|BB|BRB|52|BRB|.bb|
Bassas da India|BS|-|-|-|-|-|administered as part of French Southern and Antarctic Lands; no ISO codes assigned
Belarus|BO|BY|BLR|112|BLR|.by|
Belgium|BE|BE|BEL|56|BEL|.be|
Belize|BH|BZ|BLZ|84|BLZ|.bz|
Benin|BN|BJ|BEN|204|BEN|.bj|
Bermuda|BD|BM|BMU|60|BMU|.bm|
Bhutan|BT|BT|BTN|64|BTN|.bt|
Bolivia|BL|BO|BOL|68|BOL|.bo|
Bosnia and Herzegovina|BK|BA|BIH|70|BIH|.ba|
Botswana|BC|BW|BWA|72|BWA|.bw|
Bouvet Island|BV|BV|BVT|74|BVT|.bv|
Brazil|BR|BR|BRA|76|BRA|.br|
British Indian Ocean Territory|IO|IO|IOT|86|IOT|.io|
British Virgin Islands|VI|VG|VGB|92|VGB|.vg|
Brunei|BX|BN|BRN|96|BRN|.bn|
Bulgaria|BU|BG|BGR|100|BGR|.bg|
Burkina Faso|UV|BF|BFA|854|BFA|.bf|
Burma|BM|MM|MMR|104|MMR|.mm|ISO uses the name Myanmar
Burundi|BY|BI|BDI|108|BDI|.bi|
Cabo Verde|CV|CV|CPV|132|CPV|.cv|
Cambodia|CB|KH|KHM|116|KHM|.kh|
Cameroon|CM|CM|CMR|120|CMR|.cm|
Canada|CA|CA|CAN|124|CAN|.ca|
Cayman Islands|CJ|KY|CYM|136|CYM|.ky|
Central African Republic|CT|CF|CAF|140|CAF|.cf|
Chad|CD|TD|TCD|148|TCD|.td|
Chile|CI|CL|CHL|152|CHL|.cl|
China|CH|CN|CHN|156|CHN|.cn|see also Taiwan
Christmas Island|KT|CX|CXR|162|CXR|.cx|
Clipperton Island|IP|-|-|-|FYP|-|ISO includes with France
Cocos (Keeling) Islands|CK|CC|CCK|166|AUS|.cc|
Colombia|CO|CO|COL|170|COL|.co|
Comoros|CN|KM|COM|174|COM|.km|
Congo, Democratic Republic of the|CG|CD|COD|180|COD|.cd|formerly Zaire
Congo, Republic of the|CF|CG|COG|178|COG|.cg|
Cook Islands|CW|CK|COK|184|COK|.ck|
Coral Sea Islands|CR|-|-|-|AUS|-|ISO includes with Australia
Costa Rica|CS|CR|CRI|188|CRI|.cr|
Cote d'Ivoire|IV|CI|CIV|384|CIV|.ci|
Croatia|HR|HR|HRV|191|HRV|.hr|
Cuba|CU|CU|CUB|192|CUB|.cu|
Curacao|UC|CW|CUW|531|-|.cw|
Cyprus|CY|CY|CYP|196|CYP|.cy|
Czechia|EZ|CZ|CZE|203|CZE|.cz|
Denmark|DA|DK|DNK|208|DNK|.dk|
Dhekelia|DX|-|-|-|-|-|
Djibouti|DJ|DJ|DJI|262|DJI|.dj|
Dominica|DO|DM|DMA|212|DMA|.dm|
Dominican Republic|DR|DO|DOM|214|DOM|.do|
Ecuador|EC|EC|ECU|218|ECU|.ec|
Egypt|EG|EG|EGY|818|EGY|.eg|
El Salvador|ES|SV|SLV|222|SLV|.sv|
Equatorial Guinea|EK|GQ|GNQ|226|GNQ|.gq|
Eritrea|ER|ER|ERI|232|ERI|.er|
Estonia|EN|EE|EST|233|EST|.ee|
Eswatini|WZ|SZ|SWZ|748|SWZ|.sz|
Ethiopia|ET|ET|ETH|231|ETH|.et|
Europa Island|EU|-|-|-|-|-|administered as part of French Southern and Antarctic Lands; no ISO codes assigned
Falkland Islands (Islas Malvinas)|FK|FK|FLK|238|FLK|.fk|
Faroe Islands|FO|FO|FRO|234|FRO|.fo|
Fiji|FJ|FJ|FJI|242|FJI|.fj|
Finland|FI|FI|FIN|246|FIN|.fi|
France|FR|FR|FRA|250|FRA|.fr|ISO includes metropolitan France along with the dependencies of Clipperton Island, French Guiana, French Polynesia, French Southern and Antarctic Lands, Guadeloupe, Martinique, Mayotte, New Caledonia, Reunion, Saint Pierre and Miquelon, Wallis and Futuna
France, Metropolitan|-|FX|FXX|249|-|.fx|ISO limits to the European part of France
French Guiana|FG|GF|GUF|254|GUF|.gf|
French Polynesia|FP|PF|PYF|258|PYF|.pf|
French Southern and Antarctic Lands|FS|TF|ATF|260|ATF|.tf|GEC does not include the French-claimed portion of Antarctica (Terre Adelie)
Gabon|GB|GA|GAB|266|GAB|.ga|
Gambia, The|GA|GM|GMB|270|GMB|.gm|
Gaza Strip|GZ|PS|PSE|275|PSE|.ps|ISO identifies as Occupied Palestinian Territory
Georgia|GG|GE|GEO|268|GEO|.ge|
Germany|GM|DE|DEU|276|DEU|.de|
Ghana|GH|GH|GHA|288|GHA|.gh|
Gibraltar|GI|GI|GIB|292|GIB|.gi|
Glorioso Islands|GO|-|-|-|-|-|administered as part of French Southern and Antarctic Lands; no ISO codes assigned
Greece|GR|GR|GRC|300|GRC|.gr|For its internal communications, the European Union recommends the use of the code EL in lieu of the ISO 3166-2 code of GR
Greenland|GL|GL|GRL|304|GRL|.gl|
Grenada|GJ|GD|GRD|308|GRD|.gd|
Guadeloupe|GP|GP|GLP|312|GLP|.gp|
Guam|GQ|GU|GUM|316|GUM|.gu|
Guatemala|GT|GT|GTM|320|GTM|.gt|
Guernsey|GK|GG|GGY|831|UK|.gg|
Guinea|GV|GN|GIN|324|GIN|.gn|
Guinea-Bissau|PU|GW|GNB|624|GNB|.gw|
Guyana|GY|GY|GUY|328|GUY|.gy|
Haiti|HA|HT|HTI|332|HTI|.ht|
Heard Island and McDonald Islands|HM|HM|HMD|334|HMD|.hm|
Holy See (Vatican City)|VT|VA|VAT|336|VAT|.va|
Honduras|HO|HN|HND|340|HND|.hn|
Hong Kong|HK|HK|HKG|344|HKG|.hk|
Howland Island|HQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Hungary|HU|HU|HUN|348|HUN|.hu|
Iceland|IC|IS|ISL|352|ISL|.is|
India|IN|IN|IND|356|IND|.in|
Indonesia|ID|ID|IDN|360|IDN|.id|
Iran|IR|IR|IRN|364|IRN|.ir|
Iraq|IZ|IQ|IRQ|368|IRQ|.iq|
Ireland|EI|IE|IRL|372|IRL|.ie|
Isle of Man|IM|IM|IMN|833|UK|.im|
Israel|IS|IL|ISR|376|ISR|.il|
Italy|IT|IT|ITA|380|ITA|.it|
Jamaica|JM|JM|JAM|388|JAM|.jm|
Jan Mayen|JN|-|-|-|SJM|-|ISO includes with Svalbard
Japan|JA|JP|JPN|392|JPN|.jp|
Jarvis Island|DQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Jersey|JE|JE|JEY|832|UK|.je|
Johnston Atoll|JQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Jordan|JO|JO|JOR|400|JOR|.jo|
Juan de Nova Island|JU|-|-|-|-|-|administered as part of French Southern and Antarctic Lands; no ISO codes assigned
Kazakhstan|KZ|KZ|KAZ|398|KAZ|.kz|
Kenya|KE|KE|KEN|404|KEN|.ke|
Kingman Reef|KQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Kiribati|KR|KI|KIR|296|KIR|.ki|
Korea, North|KN|KP|PRK|408|PRK|.kp|
Korea, South|KS|KR|KOR|410|KOR|.kr|
Kosovo|KV|XK|XKS|-|-|-|XK and XKS are ISO 3166 user assigned codes; ISO 3166 Maintenace Authority has not assigned codes
Kuwait|KU|KW|KWT|414|KWT|.kw|
Kyrgyzstan|KG|KG|KGZ|417|KGZ|.kg|
Laos|LA|LA|LAO|418|LAO|.la|
Latvia|LG|LV|LVA|428|LVA|.lv|
Lebanon|LE|LB|LBN|422|LBN|.lb|
Lesotho|LT|LS|LSO|426|LSO|.ls|
Liberia|LI|LR|LBR|430|LBR|.lr|
Libya|LY|LY|LBY|434|LBY|.ly|
Liechtenstein|LS|LI|LIE|438|LIE|.li|
Lithuania|LH|LT|LTU|440|LTU|.lt|
Luxembourg|LU|LU|LUX|442|LUX|.lu|
Macau|MC|MO|MAC|446|MAC|.mo|
Madagascar|MA|MG|MDG|450|MDG|.mg|
Malawi|MI|MW|MWI|454|MWI|.mw|
Malaysia|MY|MY|MYS|458|MYS|.my|
Maldives|MV|MV|MDV|462|MDV|.mv|
Mali|ML|ML|MLI|466|MLI|.ml|
Malta|MT|MT|MLT|470|MLT|.mt|
Marshall Islands|RM|MH|MHL|584|MHL|.mh|
Martinique|MB|MQ|MTQ|474|MTQ|.mq|
Mauritania|MR|MR|MRT|478|MRT|.mr|
Mauritius|MP|MU|MUS|480|MUS|.mu|
Mayotte|MF|YT|MYT|175|FRA|.yt|
Mexico|MX|MX|MEX|484|MEX|.mx|
Micronesia, Federated States of|FM|FM|FSM|583|FSM|.fm|
Midway Islands|MQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Moldova|MD|MD|MDA|498|MDA|.md|
Monaco|MN|MC|MCO|492|MCO|.mc|
Mongolia|MG|MN|MNG|496|MNG|.mn|
Montenegro|MJ|ME|MNE|499|MNE|.me|
Montserrat|MH|MS|MSR|500|MSR|.ms|
Morocco|MO|MA|MAR|504|MAR|.ma|
Mozambique|MZ|MZ|MOZ|508|MOZ|.mz|
Myanmar|-|-|-|-|-|-|see Burma
Namibia|WA|NA|NAM|516|NAM|.na|
Nauru|NR|NR|NRU|520|NRU|.nr|
Navassa Island|BQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Nepal|NP|NP|NPL|524|NPL|.np|
Netherlands|NL|NL|NLD|528|NLD|.nl|
Netherlands Antilles|NT||||ANT|.an|disestablished in October 2010 this entity no longer exists; ISO deleted the codes in December 2010
New Caledonia|NC|NC|NCL|540|NCL|.nc|
New Zealand|NZ|NZ|NZL|554|NZL|.nz|
Nicaragua|NU|NI|NIC|558|NIC|.ni|
Niger|NG|NE|NER|562|NER|.ne|
Nigeria|NI|NG|NGA|566|NGA|.ng|
Niue|NE|NU|NIU|570|NIU|.nu|
Norfolk Island|NF|NF|NFK|574|NFK|.nf|
North Macedonia|MK|MK|MKD|807|FYR|.mk|
Northern Mariana Islands|CQ|MP|MNP|580|MNP|.mp|
Norway|NO|NO|NOR|578|NOR|.no|
Oman|MU|OM|OMN|512|OMN|.om|
Pakistan|PK|PK|PAK|586|PAK|.pk|
Palau|PS|PW|PLW|585|PLW|.pw|
Palmyra Atoll|LQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Panama|PM|PA|PAN|591|PAN|.pa|
Papua New Guinea|PP|PG|PNG|598|PNG|.pg|
Paracel Islands|PF|-|-|-|-|-|
Paraguay|PA|PY|PRY|600|PRY|.py|
Peru|PE|PE|PER|604|PER|.pe|
Philippines|RP|PH|PHL|608|PHL|.ph|
Pitcairn Islands|PC|PN|PCN|612|PCN|.pn|
Poland|PL|PL|POL|616|POL|.pl|
Portugal|PO|PT|PRT|620|PRT|.pt|
Puerto Rico|RQ|PR|PRI|630|PRI|.pr|
Qatar|QA|QA|QAT|634|QAT|.qa|
Reunion|RE|RE|REU|638|REU|.re|
Romania|RO|RO|ROU|642|ROU|.ro|
Russia|RS|RU|RUS|643|RUS|.ru|
Rwanda|RW|RW|RWA|646|RWA|.rw|
Saint Barthelemy|TB|BL|BLM|652|-|.bl|ccTLD .fr and .gp may also be used
Saint Helena, Ascension, and Tristan da Cunha|SH|SH|SHN|654|SHN|.sh|includes Saint Helena Island, Ascension Island, and the Tristan da Cunha archipelago
Saint Kitts and Nevis|SC|KN|KNA|659|KNA|.kn|
Saint Lucia|ST|LC|LCA|662|LCA|.lc|
Saint Martin|RN|MF|MAF|663|-|.mf|ccTLD .fr and .gp may also be used
Saint Pierre and Miquelon|SB|PM|SPM|666|SPM|.pm|
Saint Vincent and the Grenadines|VC|VC|VCT|670|VCT|.vc|
Samoa|WS|WS|WSM|882|WSM|.ws|
San Marino|SM|SM|SMR|674|SMR|.sm|
Sao Tome and Principe|TP|ST|STP|678|STP|.st|
Saudi Arabia|SA|SA|SAU|682|SAU|.sa|
Senegal|SG|SN|SEN|686|SEN|.sn|
Serbia|RI|RS|SRB|688|-|.rs|
Seychelles|SE|SC|SYC|690|SYC|.sc|
Sierra Leone|SL|SL|SLE|694|SLE|.sl|
Singapore|SN|SG|SGP|702|SGP|.sg|
Sint Maarten|NN|SX|SXM|534|-|.sx|
Slovakia|LO|SK|SVK|703|SVK|.sk|
Slovenia|SI|SI|SVN|705|SVN|.si|
Solomon Islands|BP|SB|SLB|90|SLB|.sb|
Somalia|SO|SO|SOM|706|SOM|.so|
South Africa|SF|ZA|ZAF|710|ZAF|.za|
South Georgia and the Islands|SX|GS|SGS|239|SGS|.gs|
South Sudan|OD|SS|SSD|728|-|-|IANA has designated .ss as the ccTLD for South Sudan, however it has not been activated in DNS root zone
Spain|SP|ES|ESP|724|ESP|.es|
Spratly Islands|PG|-|-|-|-|-|
Sri Lanka|CE|LK|LKA|144|LKA|.lk|
Sudan|SU|SD|SDN|729|SDN|.sd|
Suriname|NS|SR|SUR|740|SUR|.sr|
Svalbard|SV|SJ|SJM|744|SJM|.sj|ISO includes Jan Mayen
Sweden|SW|SE|SWE|752|SWE|.se|
Switzerland|SZ|CH|CHE|756|CHE|.ch|
Syria|SY|SY|SYR|760|SYR|.sy|
Taiwan|TW|TW|TWN|158|TWN|.tw|
Tajikistan|TI|TJ|TJK|762|TJK|.tj|
Tanzania|TZ|TZ|TZA|834|TZA|.tz|
Thailand|TH|TH|THA|764|THA|.th|
Timor-Leste|TT|TL|TLS|626|TLS|.tl|
Togo|TO|TG|TGO|768|TGO|.tg|
Tokelau|TL|TK|TKL|772|TKL|.tk|
Tonga|TN|TO|TON|776|TON|.to|
Trinidad and Tobago|TD|TT|TTO|780|TTO|.tt|
Tromelin Island|TE|-|-|-|-|-|administered as part of French Southern and Antarctic Lands; no ISO codes assigned
Tunisia|TS|TN|TUN|788|TUN|.tn|
Turkey|TU|TR|TUR|792|TUR|.tr|
Turkmenistan|TX|TM|TKM|795|TKM|.tm|
Turks and Caicos Islands|TK|TC|TCA|796|TCA|.tc|
Tuvalu|TV|TV|TUV|798|TUV|.tv|
Uganda|UG|UG|UGA|800|UGA|.ug|
Ukraine|UP|UA|UKR|804|UKR|.ua|
United Arab Emirates|AE|AE|ARE|784|ARE|.ae|
United Kingdom|UK|GB|GBR|826|GBR|.uk|for its internal communications, the European Union recommends the use of the code UK in lieu of the ISO 3166-2 code of GB
United States|US|US|USA|840|USA|.us|
United States Minor Outlying Islands|-|UM|UMI|581|-|.um|ISO includes Baker Island, Howland Island, Jarvis Island, Johnston Atoll, Kingman Reef, Midway Islands, Navassa Island, Palmyra Atoll, Wake Island
Uruguay|UY|UY|URY|858|URY|.uy|
Uzbekistan|UZ|UZ|UZB|860|UZB|.uz|
Vanuatu|NH|VU|VUT|548|VUT|.vu|
Venezuela|VE|VE|VEN|862|VEN|.ve|
Vietnam|VM|VN|VNM|704|VNM|.vn|
Virgin Islands|VQ|VI|VIR|850|VIR|.vi|
Virgin Islands (UK)|-|-|-|-|-|.vg|see British Virgin Islands
Virgin Islands (US)|-|-|-|-|-|.vi|see Virgin Islands
Wake Island|WQ|-|-|-|UMI|-|ISO includes with the US Minor Outlying Islands
Wallis and Futuna|WF|WF|WLF|876|WLF|.wf|
West Bank|WE|PS|PSE|275|PSE|.ps|ISO identifies as Occupied Palestinian Territory
Western Sahara|WI|EH|ESH|732|ESH|.eh|
Western Samoa|-|-|-|-|-|.ws|see Samoa
World|-|-|-|-|-|-|the Factbook uses the W data code from DIAM 65-18 Geopolitical Data Elements and Related Features, Data Standard No. 3, December 1994, published by the Defense Intelligence Agency
Yemen|YM|YE|YEM|887|YEM|.ye|
Zaire|-|-|-|-|-|-|see Democratic Republic of the Congo
Zambia|ZA|ZM|ZMB|894|ZMB|.zm|
Zimbabwe|ZI|ZW|ZWE|716|ZWE|.zw|
_TABLE_
}

1; # file must return true when compiled

__END__

=head1 SEARCHABLE FIELDS

For the purposes of this module, short names have been assigned to each type
of search field. These names are provided below, along with a description of
the field taken from the CIA World Handbook:

=over 4

=item name

=item gec

GEOPOLITICAL ENTITIES and CODES (formerly FIPS PUB 10-4): FIPS PUB 10-4
was withdrawn by the National Institute of Standards and Technology on 2
September 2008 based on Public Law 104-113 (codified OMB Circular A-119
and the National Technology Transfer and Advancement Act of 1995). The
National Geospatial-Intelligence Agency (NGA), as the maintenance
authority for FIPS PUB 10-4, has continued to maintain and provide
regular updates to its content in a document known as Geopolitical
Entities and Codes (GEC) (Formerly FIPS 1PUB 10-4).

=item iso2

=item iso3

=item isonum

ISO 3166: Codes for the Representation of Names of Countries (ISO 3166)
is prepared by the International Organization for Standardization. ISO
3166 includes two- and three-character alphabetic codes and three-digit
numeric codes that may be needed for activities involving exchange of
data with international organizations that have adopted that standard.
Except for the numeric codes, ISO 3166 codes have been adopted in the US
as FIPS 104-1: American National Standard Codes for the Representation
of Names of Countries, Dependencies, and Areas of Special Sovereignty
for Information Interchange.

=item nato

STANAG 1059: Letter Codes for Geographical Entities (8th edition, 2004)
is a Standardization Agreement (STANAG) established and maintained by
the North Atlantic Treaty Organization (NATO/OTAN) for the purpose of
providing a common set of geo-spatial identifiers for countries,
territories, and possessions. The 8th edition established trigraph codes
for each country based upon the ISO 3166-1 alpha-3 character sets. These
codes are used throughout NATO.

=item internet

Internet: The Internet country code is the two-letter digraph maintained
by the International Organization for Standardization (ISO) in the ISO
3166 Alpha-2 list and used by the Internet Assigned Numbers Authority
(IANA) to establish country-coded top-level domains (ccTLDs).

=back

=head1 AUTHOR

Gary Puckering

=head1 COPYRIGHT AND LICENSE

Copyright 2022 by Gary Puckering.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
