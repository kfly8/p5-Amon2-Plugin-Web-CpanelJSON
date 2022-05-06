package Amon2::Plugin::Web::CpanelJSON;
use strict;
use warnings;

use Amon2::Util ();
use Cpanel::JSON::XS ();
use Scalar::Util qw(blessed);
use HTTP::SecureHeaders;

our $VERSION = "0.01";

my %DEFAULT_CONFIG = (
    name => 'render_json',

    # for security
    secure_headers => HTTP::SecureHeaders->new(
        x_frame_options => 'DENY',
    ),

    json_escape_filter => {
        # Ref: https://cheatsheetseries.owasp.org/cheatsheets/XSS_Filter_Evasion_Cheat_Sheet.html
        # Ref: (Japanese) http://www.atmarkit.co.jp/fcoding/articles/webapp/05/webapp05a.html
        '+' => '\\u002b', # do not eval as UTF-7
        '<' => '\\u003c', # do not eval as HTML
        '>' => '\\u003e', # ditto.
    },

    # JSON config
    ascii           => !!1, # for security
    utf8            => !!0,
    canonical       => !!0,
    convert_blessed => !!0,
    require_types   => !!0,
    type_all_string => !!0,

    # for convenience
    deflate_object    => !!0,
    status_code_field => undef,

    # for compatibility options
    defence_json_hijacking_for_legacy_browser => !!0,
);

sub init {
    my ($class, $c, $conf) = @_;

    $conf = { %DEFAULT_CONFIG, %{$conf||{}} };

    my $name = $conf->{name};

    unless ($c->can($name)) {
        my $render_json = _generate_render_json($conf);
        Amon2::Util::add_method($c, $name, $render_json)
    }
}

sub _generate_render_json {
    my $conf = shift;

    my $encoder = _generate_json_encoder($conf);
    my $validator = _generate_req_validator($conf);

    return sub {
        my ($c, $data, $spec, $status) = @_;
        $status //= 200;

        if (my $error = $validator->($c)) {
            return $error;
        }

        my $output = $encoder->($data, $spec);

        my $res = do {
            my $res = $c->create_response($status);

            my $encoding = $c->encoding();
            $encoding = lc($encoding->mime_name) if ref $encoding;

            $res->content_type("application/json; charset=$encoding");
            $res->content_length(length($output));
            $res->body($output);

            if (my $secure_headers = $conf->{secure_headers}) {
                $secure_headers->apply($res->headers)
            }

            # X-API-Status
            # (Japanese) http://web.archive.org/web/20190503111531/http://blog.yappo.jp/yappo/archives/000829.html
            if (my $status_code_field =  $conf->{status_code_field}) {
                if (exists $data->{$status_code_field}) {
                    $res->header('X-API-Status' => $data->{$status_code_field})
                }
            }

            $res
        };

        return $res;
    }
}

sub _generate_json_encoder {
    my $conf = shift;
    my $json = Cpanel::JSON::XS->new()
                               ->ascii($conf->{ascii})
                               ->utf8($conf->{utf8})
                               ->canonical($conf->{canonical})
                               ->convert_blessed($conf->{convert_blessed})
                               ->require_types($conf->{require_types})
                               ->type_all_string($conf->{type_all_string});

    return sub {
        my ($data, $spec) = @_;

        if ($conf->{deflate_object}) {
            if (blessed($data) && $data->can('DEFLATE_OBJECT')) {
                $data = $data->DEFLATE_OBJECT;
            }
        }

        my $output = $json->encode($data, $spec);

        if (my $escape = $conf->{json_escape_filter}) {
            $output =~ s!([+<>])!$escape->{$1}!g;
        }

        return $output;
    }
}

sub _generate_req_validator {
    my $conf = shift;

    return sub {
        my ($c) = @_;

        # defense from JSON hijacking
        if ($conf->{defence_json_hijacking_for_legacy_browser}) {
            my $user_agent = $c->req->user_agent || '';

            if (
                (!$c->req->header('X-Requested-With')) &&
                $user_agent =~ /android/i &&
                defined $c->req->header('Cookie') &&
                ($c->req->method||'GET') eq 'GET'
            ) {
                return _error_response($c);
            }
        }
    }
}

sub _error_response {
    my $c = shift;

    my $res = $c->create_response(403);
    $res->content_type('text/plain');
    $res->content("invalid JSON request");
    $res->content_length(length $res->content);
    return $res;
}

1;
__END__

=encoding utf-8

=head1 NAME

Amon2::Plugin::Web::CpanelJSON - Cpanel::JSON::XS plugin

=head1 SYNOPSIS

    use Amon2::Lite;
    use Cpanel::JSON::XS::Type;
    use HTTP::Status qw(:constants);

    __PACKAGE__->load_plugins(qw/Web::CpanelJSON/);

    use constant HelloWorld => {
        message => JSON_TYPE_STRING,
    };

    get '/' => sub {
        my $c = shift;
        return $c->render_json(+{ message => 'HELLO!' }, HelloWorld, HTTP_OK);
    };

    __PACKAGE__->to_app();

=head1 DESCRIPTION

This is a JSON plugin for Amon2.
The differences from Amon2::Plugin::Web::JSON are as follows.

* Cpanel::JSON::XS::Type is available

* HTTP status code can be specified

* Flexible Configurations

=head1 METHODS

=over 4

=item C<< $c->render_json($data, $json_spec, $status=200); >>

Generate JSON C<< $data >> and C<< $json_spec >> and returns instance of L<Plack::Response>.
C<< $json_spec >> is a structure for JSON encoding defined in L<Cpanel::JSON::XS::Type>.

=back

=head1 CONFIGURATION

=over 4

=item name

Name of method. Default: 'render_json'

=back

=head2 Security Configurations

=over 4

=item json_escape

Default: true

=item json_hijacking

Default: true

=item nosniff

Default: true

=back

=head2 JSON Configurations

The following JSON encoding settings are available.

=over 4

=item ascii

Default: true

=item utf8

Default: true

=item canonical

Default: false

=item convert_blessed

Default: false

=item require_types

Default: false

=item type_all_string

Default: false

=back

=head2 Other Configurations

=over 4

=item deflate_object

Default: false

    __PACKAGE__->load_plugins(
        'Web::CpanelJSON' => { deflate_object => !!1 }
    );

    ...

    package Some::Object {
        use Mouse;

        has message => (
            is => 'ro',
        );

        sub DEFLATE_OBJECT {
            my $self = shift;

            return {
                message => $self->message,
            }
        }
    }

    my $object = Some::Object->new(message => 'HELLO');
    $c->render_json($object, { message => JSON_TYPE_STRING })
    # => {"message":"HELLO"}

=item status_code_field

Default: undef

It specify the field name of JSON to be embedded in the C<< X-API-Status >> header.
Default is C<< undef >>. If you set the C<< undef >> to disable this C<< X-API-Status >> header.

    __PACKAGE__->load_plugins(
        'Web::CpanelJSON' => { status_code_field => 'status' }
    );

    ...

    $c->render_json({ status => 200, message => 'ok' })
    # send response header 'X-API-Status: 200'

In general JSON API error code embed in a JSON by JSON API Response body.
But can not be logging the error code of JSON for the access log of a general Web Servers.
You can possible by using the C<< X-API-Status >> header.

=back


=head1 LICENSE

Copyright (C) kfly8.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kfly8 E<lt>kfly@cpan.orgE<gt>

=cut

