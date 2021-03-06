#!perl

use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;
use ElasticSearch::SearchBuilder;

my $a = ElasticSearch::SearchBuilder->new;

is( scalar $a->query(),      undef, 'Empty ()' );
is( scalar $a->query(undef), undef, '(undef)' );
is( scalar $a->query( [] ), undef, 'Empty []' );
is( scalar $a->query( {} ), undef, 'Empty {}' );
is( scalar $a->query( [ [], {} ] ), undef, 'Empty [[]{}]' );
is( scalar $a->query( { [], {} } ), undef, 'Empty {[]{}}' );
is( scalar $a->query( { -ids => [] } ), undef, 'IDS=>[]' );

throws_ok { $a->query( 1, 2 ) } qr/Too many params/, '1,2';
throws_ok { $a->query( [undef] ) } qr/UNDEF in arrayref/, '[undef]';

test_queries(
    'SCALAR',

    'V',
    'v',
    { text => { _all => 'v' } },

    '\\V',
    \'v',
    'v',

);

test_queries(
    'KEY-VALUE PAIRS',

    'K: V',
    { k    => 'v' },
    { text => { k => 'v' } },

    'K: UNDEF',
    { k => undef },
    qr/UNDEF not a supported query/,

    'K: \\V',
    { k => \'v' },
    { k => 'v' },

    'K: []',
    { k => [] },
    qr/UNDEF not a supported query/,

    'K: [V]',
    { k    => ['v'] },
    { text => { k => 'v' } },

    'K: [V,V]',
    { k => [ 'v', 'v' ] },
    {   bool => {
            should => [ { text => { k => 'v' } }, { text => { k => 'v' } } ]
        }
    },

    'K: [UNDEF]',
    { k => [undef] },
    qr/UNDEF not a supported query/,

    'K: [V,UNDEF]',
    { k => [ 'v', undef ] },
    qr/UNDEF not a supported query/,

    'K: [-and,V,UNDEF]',
    { k => [ '-and', 'v', undef ] },
    qr/UNDEF not a supported query/,

);

for my $op (qw(= text)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k    => { $op => 'v' } },
        { text => { k   => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k    => { $op => ['v'] } },
        { text => { k   => 'v' } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should =>
                    [ { text => { k => 'v' } }, { text => { k => 'v' } } ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query          => 'v',
                    boost          => 1,
                    operator       => 'AND',
                    analyzer       => 'default',
                    fuzziness      => 0.5,
                    max_expansions => 10,
                    prefix_length  => 2,
                }
            }
        },
        {   text => {
                k => {
                    analyzer       => 'default',
                    boost          => 1,
                    fuzziness      => '0.5',
                    max_expansions => 10,
                    operator       => 'AND',
                    prefix_length  => 2,
                    query          => 'v'
                }
            }
        },
    );
}

for my $op (qw(!= <> not_text)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { bool => { must_not => [ { text => { k => 'v' } } ] } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { bool => { must_not => [ { text => { k => 'v' } } ] } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not =>
                    [ { text => { k => 'v' } }, { text => { k => 'v' } } ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query          => 'v',
                    boost          => 1,
                    operator       => 'AND',
                    analyzer       => 'default',
                    fuzziness      => 0.5,
                    max_expansions => 10,
                    prefix_length  => 2,
                }
            }
        },
        {   bool => {
                must_not => [ {
                        text => {
                            k => {
                                analyzer       => 'default',
                                boost          => 1,
                                fuzziness      => '0.5',
                                max_expansions => 10,
                                operator       => 'AND',
                                prefix_length  => 2,
                                query          => 'v'
                            }
                        }
                    }
                ]
            }
        }
    );
}

for my $op (qw(== phrase text_phrase)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k           => { $op => 'v' } },
        { text_phrase => { k   => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k           => { $op => ['v'] } },
        { text_phrase => { k   => 'v' } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should => [
                    { text_phrase => { k => 'v' } },
                    { text_phrase => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query    => 'v',
                    boost    => 1,
                    analyzer => 'default',
                    slop     => 3,
                }
            }
        },
        {   text_phrase => {
                k => {
                    analyzer => 'default',
                    boost    => 1,
                    query    => 'v',
                    slop     => 3,
                }
            }
        },
    );
}

for my $op (qw(not_phrase not_text_phrase)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { bool => { must_not => [ { text_phrase => { k => 'v' } } ] } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { bool => { must_not => [ { text_phrase => { k => 'v' } } ] } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not => [
                    { text_phrase => { k => 'v' } },
                    { text_phrase => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query    => 'v',
                    boost    => 1,
                    analyzer => 'default',
                    slop     => 3,
                }
            }
        },
        {   bool => {
                must_not => [ {
                        text_phrase => {
                            k => {
                                analyzer => 'default',
                                boost    => 1,
                                query    => 'v',
                                slop     => 3,
                            }
                        }
                    }
                ]
            }
        },
    );
}

for my $op (qw(term terms)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k    => { $op => 'v' } },
        { term => { k   => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k    => { $op => ['v'] } },
        { term => { k   => 'v' } },

        "K: $op [V,V]",
        { k     => { $op => [ 'v', 'v' ] } },
        { terms => { k   => [ 'v', 'v' ] } },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        { k => { $op => { value => 1, boost => 1, minimum_match => 1 } } },
        { term => { k => { boost => 1, value => 1 } } },

        'K: $op {[]}',
        {   k => {
                $op => { value => [ 1, 2 ], boost => 1, minimum_match => 1 }
            }
        },
        { terms => { boost => 1, k => [ 1, 2 ], minimum_match => 1 } },

    );
}

for my $op (qw(not_term not_terms)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { bool => { must_not => [ { term => { k => 'v' } } ] } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { bool => { must_not => [ { term => { k => 'v' } } ] } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        { bool => { must_not => [ { terms => { k => [ 'v', 'v' ] } } ] } },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        { k => { $op => { value => 1, boost => 1, minimum_match => 1 } } },
        {   bool => {
                must_not =>
                    [ { term => { k => { boost => 1, value => 1 } } } ]
            }
        },

        'K: $op {[]}',
        {   k => {
                $op => { value => [ 1, 2 ], boost => 1, minimum_match => 1 }
            }
        },
        {   bool => {
                must_not => [ {
                        terms =>
                            { boost => 1, k => [ 1, 2 ], minimum_match => 1 }
                    }
                ]
            }
        },

    );
}

for my $op (qw(^ phrase_prefix text_phrase_prefix)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k                  => { $op => 'v' } },
        { text_phrase_prefix => { k   => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k                  => { $op => ['v'] } },
        { text_phrase_prefix => { k   => 'v' } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should => [
                    { text_phrase_prefix => { k => 'v' } },
                    { text_phrase_prefix => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query          => 'v',
                    boost          => 1,
                    analyzer       => 'default',
                    slop           => 10,
                    max_expansions => 10
                }
            }
        },
        {   text_phrase_prefix => {
                k => {
                    query          => 'v',
                    boost          => 1,
                    analyzer       => 'default',
                    slop           => 10,
                    max_expansions => 10

                }
            }
        }
    );
}

for my $op (qw(not_phrase_prefix not_text_phrase_prefix)) {

    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        {   bool => { must_not => [ { text_phrase_prefix => { k => 'v' } } ] }
        },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        {   bool => { must_not => [ { text_phrase_prefix => { k => 'v' } } ] }
        },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not => [
                    { text_phrase_prefix => { k => 'v' } },
                    { text_phrase_prefix => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query          => 'v',
                    boost          => 1,
                    analyzer       => 'default',
                    slop           => 10,
                    max_expansions => 10
                }
            }
        },
        {   bool => {
                must_not => [ {
                        text_phrase_prefix => {
                            k => {
                                query          => 'v',
                                boost          => 1,
                                analyzer       => 'default',
                                slop           => 10,
                                max_expansions => 10

                            }
                        }
                    }
                ]
            }
        }

    );
}

for my $op (qw(prefix)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k      => { $op => 'v' } },
        { prefix => { k   => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k      => { $op => ['v'] } },
        { prefix => { k   => 'v' } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should => [
                    { prefix => { k => 'v' } }, { prefix => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        { k      => { $op => { value => 'v', boost => 1 } } },
        { prefix => { k   => { value => 'v', boost => 1 } } },
    );
}

for my $op (qw(not_prefix)) {

    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { bool => { must_not => [ { prefix => { k => 'v' } } ] } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { bool => { must_not => [ { prefix => { k => 'v' } } ] } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not => [
                    { prefix => { k => 'v' } }, { prefix => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        { k => { $op => { value => 'v', boost => 1 } } },
        {   bool => {
                must_not =>
                    [ { prefix => { k => { value => 'v', boost => 1 } } } ]
            }
        },
    );
}

for my $op (qw(* wildcard)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k        => { $op => 'v' } },
        { wildcard => { k   => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k        => { $op => ['v'] } },
        { wildcard => { k   => 'v' } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should => [
                    { wildcard => { k => 'v' } },
                    { wildcard => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        { k        => { $op => { value => 'v', boost => 1 } } },
        { wildcard => { k   => { value => 'v', boost => 1 } } },
    );
}

for my $op (qw(not_wildcard)) {

    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { bool => { must_not => [ { wildcard => { k => 'v' } } ] } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { bool => { must_not => [ { wildcard => { k => 'v' } } ] } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not => [
                    { wildcard => { k => 'v' } },
                    { wildcard => { k => 'v' } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        { k => { $op => { value => 'v', boost => 1 } } },
        {   bool => {
                must_not =>
                    [ { wildcard => { k => { value => 'v', boost => 1 } } } ]
            }
        },
    );
}

for my $op (qw(fuzzy)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k     => { $op => 'v' } },
        { fuzzy => { k   => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k     => { $op => ['v'] } },
        { fuzzy => { k   => 'v' } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should =>
                    [ { fuzzy => { k => 'v' } }, { fuzzy => { k => 'v' } } ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    value          => 'v',
                    boost          => 1,
                    min_similarity => 0.5,
                    max_expansions => 10,
                    prefix_length  => 2
                }
            }
        },
        {   fuzzy => {
                k => {
                    value          => 'v',
                    boost          => 1,
                    min_similarity => 0.5,
                    max_expansions => 10,
                    prefix_length  => 2
                }
            }
        },
    );
}

for my $op (qw(not_fuzzy)) {

    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { bool => { must_not => [ { fuzzy => { k => 'v' } } ] } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { bool => { must_not => [ { fuzzy => { k => 'v' } } ] } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not =>
                    [ { fuzzy => { k => 'v' } }, { fuzzy => { k => 'v' } } ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    value          => 'v',
                    boost          => 1,
                    min_similarity => 0.5,
                    max_expansions => 10,
                    prefix_length  => 2
                }
            }
        },
        {   bool => {
                must_not => [ {
                        fuzzy => {
                            k => {
                                value          => 'v',
                                boost          => 1,
                                min_similarity => 0.5,
                                max_expansions => 10,
                                prefix_length  => 2
                            }
                        }
                    }
                ]
            }
        },
    );
}

my %range_map = (
    '<'  => 'lt',
    '<=' => 'lte',
    '>'  => 'gt',
    '>=' => 'gte'
);

for my $op (qw(< <= >= > gt gte lt lte)) {
    my $type = 'range';
    my $es_op = $range_map{$op} || $op;

    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { $type => { k => { $es_op => 'v' } } },

        "K: $op UNDEF",
        { $type => { $op => undef } },
        qr/SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        qr/SCALAR/,

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        qr/SCALAR/,

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/SCALAR/,

        'K[$op 5],K[$op 10]',
        { k => [ -and => { '>' => 5 }, { '>' => 10 } ] },
        qr/Duplicate/,
    );
}

test_queries(
    "COMBINED RANGE OPERATORS",

    "K: gt gte lt lte V",
    {   k => {
            gt  => 'v',
            gte => 'v',
            lt  => 'v',
            lte => 'v',
        }
    },
    { range => { k => { gt => 'v', gte => 'v', lt => 'v', lte => 'v' } } },

    "K: < <= > >= V",
    {   k => {
            '>'  => 'v',
            '>=' => 'v',
            '<'  => 'v',
            '<=' => 'v'
        }
    },
    { range => { k => { gt => 'v', gte => 'v', lt => 'v', lte => 'v' } } },

    "K: [gt gte lt lte < <= > >=] V",
    {   k => [
            { gt   => 'v' },
            { gte  => 'v' },
            { lt   => 'v' },
            { lte  => 'v' },
            { '>'  => 'V' },
            { '>=' => 'V' },
            { '<'  => 'V' },
            { '<=' => 'V' }
        ]
    },
    {   bool => {
            should => [
                { range => { k => { gt  => "v" } } },
                { range => { k => { gte => "v" } } },
                { range => { k => { lt  => "v" } } },
                { range => { k => { lte => "v" } } },
                { range => { k => { gt  => "V" } } },
                { range => { k => { gte => "V" } } },
                { range => { k => { lt  => "V" } } },
                { range => { k => { lte => "V" } } },
            ],
        }
    },

    "K: range {}",
    {   k => {
            range => {
                from          => 1,
                to            => 2,
                include_lower => 1,
                include_upper => 1,
                gt            => 1,
                gte           => 1,
                lt            => 2,
                lte           => 2,
                boost         => 1
            }
        }
    },
    {   range => {
            k => {
                from          => 1,
                to            => 2,
                include_lower => 1,
                include_upper => 1,
                gt            => 1,
                gte           => 1,
                lt            => 2,
                lte           => 2,
                boost         => 1
            }
        }
    }
);

for my $op (qw(flt)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { flt_field => { k => { like_text => 'v' } } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { flt_field => { k => { like_text => 'v' } } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should => [
                    { flt_field => { k => { like_text => 'v' } } },
                    { flt_field => { k => { like_text => 'v' } } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    like_text      => 'v',
                    boost          => 1,
                    min_similarity => 0.5,
                    ignore_tf      => 1,
                    prefix_length  => 2,
                    analyzer       => 'default',
                }
            }
        },
        {   flt_field => {
                k => {
                    like_text      => 'v',
                    boost          => 1,
                    min_similarity => 0.5,
                    ignore_tf      => 1,
                    prefix_length  => 2,
                    analyzer       => 'default',
                }
            }
        },
    );
}

for my $op (qw(not_flt)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        {   bool => {
                must_not => [ { flt_field => { k => { like_text => 'v' } } } ]
            }
        },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        {   bool => {
                must_not => [ { flt_field => { k => { like_text => 'v' } } } ]
            }
        },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not => [
                    { flt_field => { k => { like_text => 'v' } } },
                    { flt_field => { k => { like_text => 'v' } } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    like_text      => 'v',
                    boost          => 1,
                    min_similarity => 0.5,
                    ignore_tf      => 1,
                    prefix_length  => 2,
                    analyzer       => 'default',
                }
            }
        },
        {   bool => {
                must_not => [ {
                        flt_field => {
                            k => {
                                like_text      => 'v',
                                boost          => 1,
                                min_similarity => 0.5,
                                ignore_tf      => 1,
                                prefix_length  => 2,
                                analyzer       => 'default',
                            }
                        }
                    }
                ]
            }
        },
    );
}

for my $op (qw(mlt)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        { mlt_field => { k => { like_text => 'v' } } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        { mlt_field => { k => { like_text => 'v' } } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should => [
                    { mlt_field => { k => { like_text => 'v' } } },
                    { mlt_field => { k => { like_text => 'v' } } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    like_text              => 'v',
                    boost                  => 1,
                    boost_terms            => 1,
                    max_doc_freq           => 100,
                    max_query_terms        => 100,
                    max_word_len           => 20,
                    min_doc_freq           => 1,
                    min_term_freq          => 1,
                    min_word_len           => 1,
                    percent_terms_to_match => 0.3,
                    stop_words             => [ 'foo', 'bar' ],
                    analyzer               => 'default',
                }
            }
        },
        {   mlt_field => {
                k => {

                    like_text              => 'v',
                    boost                  => 1,
                    boost_terms            => 1,
                    max_doc_freq           => 100,
                    max_query_terms        => 100,
                    max_word_len           => 20,
                    min_doc_freq           => 1,
                    min_term_freq          => 1,
                    min_word_len           => 1,
                    percent_terms_to_match => 0.3,
                    stop_words             => [ 'foo', 'bar' ],
                    analyzer               => 'default',
                }
            }
        },
    );
}

for my $op (qw(not_mlt)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k => { $op => 'v' } },
        {   bool => {
                must_not => [ { mlt_field => { k => { like_text => 'v' } } } ]
            }
        },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k => { $op => ['v'] } },
        {   bool => {
                must_not => [ { mlt_field => { k => { like_text => 'v' } } } ]
            }
        },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not => [
                    { mlt_field => { k => { like_text => 'v' } } },
                    { mlt_field => { k => { like_text => 'v' } } }
                ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    like_text              => 'v',
                    boost                  => 1,
                    boost_terms            => 1,
                    max_doc_freq           => 100,
                    max_query_terms        => 100,
                    max_word_len           => 20,
                    min_doc_freq           => 1,
                    min_term_freq          => 1,
                    min_word_len           => 1,
                    percent_terms_to_match => 0.3,
                    stop_words             => [ 'foo', 'bar' ],
                    analyzer               => 'default',
                }
            }
        },
        {   bool => {
                must_not => [ {
                        mlt_field => {
                            k => {
                                like_text              => 'v',
                                boost                  => 1,
                                boost_terms            => 1,
                                max_doc_freq           => 100,
                                max_query_terms        => 100,
                                max_word_len           => 20,
                                min_doc_freq           => 1,
                                min_term_freq          => 1,
                                min_word_len           => 1,
                                percent_terms_to_match => 0.3,
                                stop_words             => [ 'foo', 'bar' ],
                                analyzer               => 'default',
                            }
                        }
                    }
                ]
            }
        },
    );
}

for my $op (qw(query_string qs)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k     => { $op => 'v' } },
        { field => { k   => => 'v' } },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k     => { $op => ['v'] } },
        { field => { k   => 'v' } },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                should =>
                    [ { field => { k => 'v' } }, { field => { k => 'v' } } ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query                        => 'v',
                    default_operator             => 'AND',
                    analyzer                     => 'default',
                    allow_leading_wildcard       => 0,
                    lowercase_expanded_terms     => 1,
                    enable_position_increments   => 1,
                    fuzzy_prefix_length          => 2,
                    fuzzy_min_sim                => 0.5,
                    phrase_slop                  => 10,
                    boost                        => 1,
                    analyze_wildcard             => 1,
                    auto_generate_phrase_queries => 0,
                }
            }
        },
        {   field => {
                k => {
                    query                        => 'v',
                    default_operator             => 'AND',
                    analyzer                     => 'default',
                    allow_leading_wildcard       => 0,
                    lowercase_expanded_terms     => 1,
                    enable_position_increments   => 1,
                    fuzzy_prefix_length          => 2,
                    fuzzy_min_sim                => 0.5,
                    phrase_slop                  => 10,
                    boost                        => 1,
                    analyze_wildcard             => 1,
                    auto_generate_phrase_queries => 0,
                }
            }
        },
    );
}

for my $op (qw(not_query_string not_qs)) {
    test_queries(
        "FIELD OPERATOR: $op",

        "K: $op V",
        { k    => { $op => 'v' } },
        { bool => {
                must_not => [ { field => { k => 'v' } } ]
            }
        },

        "K: $op UNDEF",
        { k => { $op => undef } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V]",
        { k    => { $op => ['v'] } },
        { bool => {
                must_not => [ { field => { k => 'v' } } ]
            }
        },

        "K: $op [V,V]",
        { k => { $op => [ 'v', 'v' ] } },
        {   bool => {
                must_not =>
                    [ { field => { k => 'v' } }, { field => { k => 'v' } } ]
            }
        },

        "K: $op [UNDEF]",
        { k => { $op => [undef] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        "K: $op [V,UNDEF]",
        { k => { $op => [ 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op [-and,V,UNDEF]',
        { k => { $op => [ '-and', 'v', undef ] } },
        qr/ARRAYREF, HASHREF, SCALAR/,

        'K: $op {}',
        {   k => {
                $op => {
                    query                        => 'v',
                    default_operator             => 'AND',
                    analyzer                     => 'default',
                    allow_leading_wildcard       => 0,
                    lowercase_expanded_terms     => 1,
                    enable_position_increments   => 1,
                    fuzzy_prefix_length          => 2,
                    fuzzy_min_sim                => 0.5,
                    phrase_slop                  => 10,
                    boost                        => 1,
                    analyze_wildcard             => 1,
                    auto_generate_phrase_queries => 0,
                }
            }
        },
        {   bool => {
                must_not => [ {
                        field => {
                            k => {
                                query                        => 'v',
                                default_operator             => 'AND',
                                analyzer                     => 'default',
                                allow_leading_wildcard       => 0,
                                lowercase_expanded_terms     => 1,
                                enable_position_increments   => 1,
                                fuzzy_prefix_length          => 2,
                                fuzzy_min_sim                => 0.5,
                                phrase_slop                  => 10,
                                boost                        => 1,
                                analyze_wildcard             => 1,
                                auto_generate_phrase_queries => 0,
                            }
                        }
                    }
                ]
            }
        },
    );
}

done_testing();

#===================================
sub test_queries {
#===================================
    note "\n" . shift();
    while (@_) {
        my $name = shift;
        my $in   = shift;
        my $out  = shift;
        if ( ref $out eq 'Regexp' ) {
            throws_ok { $a->query($in) } $out, $name;
        }
        else {
            eval {
                eq_or_diff scalar $a->query($in), { query => $out }, $name;
                1;
            }
                or die "*** FAILED TEST $name:***\n$@";
        }
    }
}
