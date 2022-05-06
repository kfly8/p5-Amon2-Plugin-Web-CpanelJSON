use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Cpanel::JSON::XS::Type;

{
    package MyApp::Web;
    use parent qw(Amon2 Amon2::Web);
    __PACKAGE__->load_plugins('Web::CpanelJSON', { name => 'my_json' });
    sub encoding { 'utf-8' }
}

my $app = MyApp::Web->to_app;

test_psgi $app, sub {
    my $cb  = shift;

    no warnings qw(once);

    subtest 'cannot call render_json' => sub {
        local *MyApp::Web::dispatch = sub {
            my $c = shift;
            $c->render_json({ hello => 'world' })
        };

        my $res = $cb->(GET "/");
        is $res->code, 500;
        like $res->content, qr/Can't locate object method "render_json" via package "MyApp::Web"/;
    };

    subtest 'call my_json' => sub {
        local *MyApp::Web::dispatch = sub {
            my $c = shift;
            $c->my_json({ hello => 'world' })
        };

        my $res = $cb->(GET "/");
        is $res->code, 200;
        is $res->content, '{"hello":"world"}'
    };
};

done_testing;
