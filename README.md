[![Actions Status](https://github.com/kfly8/p5-Amon2-Plugin-Web-CpanelJSON/workflows/test/badge.svg)](https://github.com/kfly8/p5-Amon2-Plugin-Web-CpanelJSON/actions)
# NAME

Amon2::Plugin::Web::CpanelJSON - Cpanel::JSON::XS plugin

# SYNOPSIS

```perl
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
```

# DESCRIPTION

This is a JSON plugin for Amon2.
The differences from Amon2::Plugin::Web::JSON are as follows.

\* Cpanel::JSON::XS::Type is available

\* HTTP status code can be specified

\* Flexible Configurations

# METHODS

- `$c->render_json($data, $json_spec, $status=200);`

    Generate JSON `$data` and `$json_spec` and returns instance of [Plack::Response](https://metacpan.org/pod/Plack%3A%3AResponse).
    `$json_spec` is a structure for JSON encoding defined in [Cpanel::JSON::XS::Type](https://metacpan.org/pod/Cpanel%3A%3AJSON%3A%3AXS%3A%3AType).

# CONFIGURATION

- name

    Name of method. Default: 'render\_json'

## Security Configurations

- json\_escape

    Default: true

- json\_hijacking

    Default: true

- nosniff

    Default: true

## JSON Configurations

The following JSON encoding settings are available.

- ascii

    Default: true

- utf8

    Default: true

- canonical

    Default: false

- convert\_blessed

    Default: false

- require\_types

    Default: false

- type\_all\_string

    Default: false

## Other Configurations

- deflate\_object

    Default: false

    ```perl
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
    ```

- status\_code\_field

    Default: undef

    It specify the field name of JSON to be embedded in the `X-API-Status` header.
    Default is `undef`. If you set the `undef` to disable this `X-API-Status` header.

    ```perl
    __PACKAGE__->load_plugins(
        'Web::CpanelJSON' => { status_code_field => 'status' }
    );

    ...

    $c->render_json({ status => 200, message => 'ok' })
    # send response header 'X-API-Status: 200'
    ```

    In general JSON API error code embed in a JSON by JSON API Response body.
    But can not be logging the error code of JSON for the access log of a general Web Servers.
    You can possible by using the `X-API-Status` header.

# LICENSE

Copyright (C) kfly8.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

kfly8 <kfly@cpan.org>
