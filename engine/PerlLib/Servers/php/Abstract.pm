=head1 NAME

 Servers::php::Abstract - i-MSCP PHP server abstract class

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2017 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package Servers::php::Abstract;

use strict;
use warnings;
use File::Basename;
use File::Spec;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::TemplateParser qw/ processByRef getBlocByRef replaceBlocByRef /;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 i-MSCP PHP server implementation.

 TODO (Enterprise Edition):
 - Depending of selected Httpd server, customer should be able to choose between several SAPI:
  - Apache2 with MPM Event, Worker or Prefork: cgi or fpm
  - Apache2 with MPM ITK                     : apache2handler or fpm
  - Nginx (Implementation not available yet) : fpm
 - Customer should be able to select the PHP version to use (Merge of PhpSwitcher feature in core)

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
    my ($self) = @_;

    eval { $self->_guessVariablesForSelectedPhpAlternative(); };
    if($@) {
        error( $@);
        return 1;
    }

    1;
}

=item setEnginePermissions( )

 Set engine permissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    return 0 unless $self->{'config'}->{'PHP_SAPI'} eq 'cgi';

    setRights( $self->{'config'}->{'PHP_FCGI_STARTER_DIR'},
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0555'
        }
    );
}

=item addDomain( \%moduleData )

 Process addDomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpAddDomain( \%moduleData )
  - afterPhpAddDomain( \%moduleData )

 Param hashref \%moduleData Data as provided by Alias|Domain modules
 Return int 0 on success, other on failure

=cut

sub addDomain
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the addDomain() method', ref $self ));
}

=item disableDomain( \%moduleData )

 Process disableDomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpdDisableDomain( \%moduleData )
  - afterPhpDisableDomain( \%moduleData )

 Param hashref \%moduleData Data as provided by Alias|Domain modules
 Return int 0 on success, other on failure

=cut

sub disableDomain
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the addDomain() method', ref $self ));
}

=item deleteDomain( \%moduleData )

 Process deleteDomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpDeleteDomain( \%moduleData )
  - afterPhpdDeleteDomain( \%moduleData )

 Param hashref \%moduleData Data as provided by Alias|Domain modules
 Return int 0 on success, other on failure

=cut

sub deleteDomain
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the addDomain() method', ref $self ));
}

=item addSubbdomain( \%moduleData )

 Process addSubbdomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpAddSubdomain( \%moduleData )
  - afterPhpAddSubdomain( \%moduleData )

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return int 0 on success, other on failure

=cut

sub addSubbdomain
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the addDomain() method', ref $self ));
}

=item disableSub( \%moduleData )

 Process disableSub tasks
 
  The following events *MUST* be triggered:
  - beforePhpDisableSubdomain( \%moduleData )
  - afterPhpdDisableSubdomain( \%moduleData )

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return int 0 on success, other on failure

=cut

sub disableSub
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the addDomain() method', ref $self ));
}

=item deleteSubdomain( \%moduleData )

 Process deleteSubdomain tasks
 
  The following events *MUST* be triggered:
  - beforePhpDeleteSubdomain( \%moduleData )
  - afterPhpDeleteSubdomain( \%moduleData )

 Param hashref \%moduleData Data as provided by SubAlias|Subdomain modules
 Return int 0 on success, other on failure

=cut

sub deleteSubdomain
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the addDomain() method', ref $self ));
}

=item buildConfFile( $srcFile, $trgFile, [, \%moduleData = { } [, \%serverData [, \%parameters = { } ] ] ] )

 Build the given PHP configuration file

 Param string $srcFile Source file path (full path or path relative to the i-MSCP php configuration directory)
 Param string $trgFile Target file path
 Param hashref \%data OPTIONAL Data as provided by Alias|Domain|SubAlias|Subdomain modules
 Param hashref \%data OPTIONAL Server data (Server data have higher precedence than modules data)
 Param hashref \%parameters OPTIONAL parameters:
  - user  : File owner (default: root)
  - group : File group (default: root
  - mode  : File mode (default: 0644)
  - cached : Whether or not loaded file must be cached in memory
 Return int 0 on success, other on failure

=cut

sub buildConfFile
{
    my ($self, $srcFile, $trgFile, $moduleData, $serverData, $parameters) = @_;
    $moduleData //= {};
    $serverData //= {};
    $parameters //= {};

    my ($filename, $path) = fileparse( $srcFile );
    my $cfgTpl;

    if ( $parameters->{'cached'} && exists $self->{'_templates'}->{$srcFile} ) {
        $cfgTpl = $self->{'_templates'}->{$srcFile};
    } else {
        my $rs = $self->{'eventManager'}->trigger(
            'onLoadTemplate', 'php', $filename, \$cfgTpl, $moduleData, $serverData, $self->{'config'}, $parameters
        );
        return $rs if $rs;

        unless ( defined $cfgTpl ) {
            $srcFile = File::Spec->canonpath( "$self->{'cfgDir'}/$path/$filename" ) if index( $path, '/' ) != 0;
            $cfgTpl = iMSCP::File->new( filename => $srcFile )->get();
            unless ( defined $cfgTpl ) {
                error( sprintf( "Couldn't read the %s file", $srcFile ));
                return 1;
            }
        }

        $self->{'_templates'}->{$srcFile} = $cfgTpl if $parameters->{'cached'};
    }

    my $rs = $self->{'eventManager'}->trigger(
        'beforePhpBuildConfFile', \$cfgTpl, $filename, \$trgFile, $moduleData, $serverData, $self->{'config'}, $parameters
    );
    return $rs if $rs;

    processByRef( $serverData, \$cfgTpl );
    processByRef( $moduleData, \$cfgTpl );

    $rs = $self->{'eventManager'}->trigger(
        'afterPhpdBuildConfFile', \$cfgTpl, $filename, \$trgFile, $moduleData, $serverData, $self->{'config'}, $parameters
    );
    return $rs if $rs;

    my $fh = iMSCP::File->new( filename => $trgFile );
    $fh->set( $cfgTpl );
    $rs ||= $fh->save();
    return $rs if $rs;

    if ( exists $parameters->{'user'} || exists $parameters->{'group'} ) {
        $rs = $fh->owner( $parameters->{'user'} // $main::imscpConfig{'ROOT_USER'}, $parameters->{'group'} // $main::imscpConfig{'ROOT_GROUP'} );
        return $rs if $rs;
    }

    if ( exists $parameters->{'mode'} ) {
        $rs = $fh->mode( $parameters->{'mode'} );
        return $rs if $rs;
    }

    # On configuration file change, schedule server reload
    $self->{'reload'} ||= 1;
    0;
}

=item start( [ $version = $self->{'config'}->{'PHP_VERSION'} ] )

 Start PHP FastCGI Process Manager 'PHP-FPM' for the given PHP version (default to selected PHP alternative for customers)

  The following events *MUST* be triggered:
  - beforePhpDeleteSubdomain( \%moduleData )
  - afterPhpDeleteSubdomain( \%moduleData )

 Param string $version OPTIONAL PHP-FPM version to start
 Return int 0 on success, other on failure

=cut

sub start
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the start() method', ref $self ));
}

=item stop( [ $version = $self->{'config'}->{'PHP_VERSION'} ] )

 Stop PHP FastCGI Process Manager 'PHP-FPM' for the given PHP version (default to selected PHP alternative for customers)

  The following events *MUST* be triggered:
  - beforePhpFpmStop( $version )
  - afterPhpFpmStop( $version )

 Param string $version OPTIONAL PHP-FPM version to stop
 Return int 0 on success, other on failure

=cut

sub stop
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the stop() method', ref $self ));
}

=item reload( [ $version = $self->{'config'}->{'PHP_VERSION'} ] )

 Reload PHP FastCGI Process Manager 'PHP-FPM' for the given PHP version (default to selected PHP alternative for customers)

  The following events *MUST* be triggered:
  - beforePhpFpmReload( $version )
  - afterPhpFpmReload( $version )

 Param string $version OPTIONAL PHP-FPM version to reload
 Return int 0

=cut

sub reload
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the reload() method', ref $self ));
}

=item restart( [ $version = $self->{'config'}->{'PHP_VERSION'} ] )

 Restart PHP FastCGI Process Manager 'PHP-FPM' for the given PHP version (default to selected PHP alternative for customers)

  The following events *MUST* be triggered:
  - beforePhpFpmRestart( $version )
  - afterPhpFpmRestart( $version )

 Param string $version OPTIONAL PHP-FPM version to restart
 Return int 0 on success, other on failure

=cut

sub restart
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the restart() method', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Servers::php::Abstract

=cut

sub _init
{
    my ($self) = @_;

    @{$self}{qw/ start restart reload _templates /} = ( 0, 0, 0, {} );
    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'cfgDir'} = "$main::imscpConfig{'CONF_DIR'}/php";
    $self->_mergeConfig() if defined $main::execmode && $main::execmode eq 'setup' && -f "$self->{'cfgDir'}/php.data.dist";
    tie %{$self->{'config'}},
        'iMSCP::Config',
        fileName    => "$self->{'cfgDir'}/php.data",
        readonly    => !( defined $main::execmode && $main::execmode eq 'setup' ),
        nodeferring => defined $main::execmode && $main::execmode eq 'setup';
    $self->{'eventManager'}->register( [ qw/ beforeApache2BuildConfFile afterApache2AddFiles / ], $self, 100 );
    $self;
}

=item _mergeConfig()

 Merge distribution configuration with production configuration

 Die on failure

=cut

sub _mergeConfig
{
    my ($self) = @_;

    if ( -f "$self->{'cfgDir'}/php.data" ) {
        tie my %newConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/php.data.dist";
        tie my %oldConfig, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/php.data", readonly => 1;

        debug( 'Merging old configuration with new configuration ...' );

        while ( my ($key, $value) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/php.data.dist" )->moveFile( "$self->{'cfgDir'}/php.data" ) == 0 or die(
        getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
    );
}

=item _guessVariablesForSelectedPhpAlternative( )

 Guess variable for the selected PHP alternative

 Return void, die on failure

=cut

sub _guessVariablesForSelectedPhpAlternative
{
    my ($self) = @_;

    die( sprintf( 'The %s package must implement the _guessVariablesForSelectedPhpAlternative() method', ref $self ));
}

=item _buildApache2HandlerConfig( \%moduleData )

 Build PHP apache2handler configuration for the given domain
 
 There are nothing special to do here. We trigger events for consistency reasons.

 Param hashref \%moduleData Data as provided by Alias|Domain|SubAlias|Subdomain modules
 Return int 0 on sucess, other on failure

=cut

sub _buildApache2HandlerConfig
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpApache2HandlerSapiBuildConf', $moduleData );
    $rs ||= $self->{'eventManager'}->trigger( 'afterPhpApache2HandlerSapiBuildConf', $moduleData );
}

=item _buildCgiConfig( \%moduleData )

 Build PHP cgi configuration for the given domain

 Param hashref \%moduleData Data as provided by Alias|Domain|SubAlias|Subdomain modules
 Return int 0 on sucess, other on failure

=cut

sub _buildCgiConfig
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpCgiSapiBuildConf', $moduleData );
    return $rs if $rs;

    my ($phpConfigLevel, $emailDomain);
    if ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_user' ) {
        $phpConfigLevel = $moduleData->{'ROOT_DOMAIN_NAME'};
        $emailDomain = $moduleData->{'ROOT_DOMAIN_NAME'};
    } elsif ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_domain' ) {
        $phpConfigLevel = $moduleData->{'PARENT_DOMAIN_NAME'};
        $emailDomain = $moduleData->{'PARENT_DOMAIN_NAME'};
    } else {
        $phpConfigLevel = $moduleData->{'DOMAIN_NAME'};
        $emailDomain = $moduleData->{'DOMAIN_NAME'};
    }

    if ( $moduleData->{'FORWARD'} eq 'no' && $moduleData->{'PHP_SUPPORT'} eq 'yes' ) {
        eval {
            iMSCP::Dir->new( dirname => "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$phpConfigLevel" )->remove();
            iMSCP::Dir->new( dirname => $self->{'config'}->{'PHP_FCGI_STARTER_DIR'} )->make( {
                user  => $main::imscpConfig{'ROOT_USER'},
                group => $main::imscpConfig{'ROOT_GROUP'},
                mode  => 0555
            } );

            for ( "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$phpConfigLevel",
                "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$phpConfigLevel/php$self->{'config'}->{'PHP_VERSION'}"
            ) {
                iMSCP::Dir->new( dirname => $_ )->make( {
                    user  => $moduleData->{'USER'},
                    group => $moduleData->{'GROUP'},
                    mode  => 0550
                } );
            }
        };
        if ( $@ ) {
            error( $@ );
            return 1;
        }

        my $serverData = {
            EMAIL_DOMAIN          => $emailDomain,
            PHP_CONFIG_LEVEL      => $phpConfigLevel,
            PHP_VERSION           => $self->{'config'}->{'PHP_VERSION'},
            PHP_FCGI_BIN_PATH     => $self->{'config'}->{'PHP_FCGI_BIN_PATH'},
            PHP_FCGI_CHILDREN     => $self->{'config'}->{'PHP_FCGI_CHILDREN'},
            PHP_FCGI_MAX_REQUESTS => $self->{'config'}->{'PHP_FCGI_MAX_REQUESTS'},
            TMPDIR                => $moduleData->{'HOME_DIR'} . '/phptmp'
        };

        $rs = $self->buildConfFile(
            'cgi/php-fcgi-starter',
            "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$phpConfigLevel/php-fcgi-starter",
            $moduleData,
            $serverData,
            {
                user   => $moduleData->{'USER'},
                group  => $moduleData->{'GROUP'},
                mode   => 0550,
                cached => 1
            }
        );
        $rs ||= $self->buildConfFile(
            'cgi/php.ini.user',
            "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$phpConfigLevel/php$self->{'config'}->{'PHP_VERSION'}/php.ini",
            $moduleData,
            $serverData,
            {
                user   => $moduleData->{'USER'},
                group  => $moduleData->{'GROUP'},
                mode   => 0440,
                cached => 1
            }
        );
        return $rs if $rs;
    } elsif ( $moduleData->{'PHP_SUPPORT'} ne 'yes'
        || ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_user' && $moduleData->{'DOMAIN_TYPE'} ne 'dmn' )
        || ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_domain' && $moduleData->{'DOMAIN_TYPE'} !~ /^(?:dmn|als)$/ )
        || $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_site'
    ) {
        eval { iMSCP::Dir->new( dirname => "$self->{'config'}->{'PHP_FCGI_STARTER_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->remove(); };
        if ( $@ ) {
            error( $@ );
            return 1;
        }
    }

    $self->{'eventManager'}->trigger( 'afterPhpCgiSapiBuildConf', $moduleData );
}

=item _buildFpmConfig( \%moduleData )

 Build PHP fpm configuration for the given domain

 Param hashref \%moduleData Data as provided by Alias|Domain|SubAlias|Subdomain modules
 Return int 0 on sucess, other on failure

=cut

sub _buildFpmConfig
{
    my ($self, $moduleData) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforePhpFpmSapiBuildConf', $moduleData );
    return $rs if $rs;

    my ($phpConfigLevel, $emailDomain);
    if ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_user' ) {
        $phpConfigLevel = $moduleData->{'ROOT_DOMAIN_NAME'};
        $emailDomain = $moduleData->{'ROOT_DOMAIN_NAME'};
    } elsif ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_domain' ) {
        $phpConfigLevel = $moduleData->{'PARENT_DOMAIN_NAME'};
        $emailDomain = $moduleData->{'DOMAIN_NAME'};
    } else {
        $phpConfigLevel = $moduleData->{'DOMAIN_NAME'};
        $emailDomain = $moduleData->{'DOMAIN_NAME'};
    }

    if ( $moduleData->{'FORWARD'} eq 'no' && $moduleData->{'PHP_SUPPORT'} eq 'yes' ) {
        my $serverData = {
            EMAIL_DOMAIN                 => $emailDomain,
            PHP_CONFIG_LEVEL             => $phpConfigLevel,
            PHP_FPM_LISTEN_ENDPOINT      => ( $self->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'uds' )
                ? "/run/php/php{PHP_VERSION}-fpm-{PHP_CONFIG_LEVEL}.sock"
                : '127.0.0.1:' . ( $self->{'config'}->{'PHP_FPM_LISTEN_PORT_START'}+$moduleData->{'PHP_FPM_LISTEN_PORT'} ),
            PHP_FPM_MAX_CHILDREN         => $self->{'config'}->{'PHP_FPM_MAX_CHILDREN'} // 6,
            PHP_FPM_MAX_REQUESTS         => $self->{'config'}->{'PHP_FPM_MAX_REQUESTS'} // 1000,
            PHP_FPM_MAX_SPARE_SERVERS    => $self->{'config'}->{'PHP_FPM_MAX_SPARE_SERVERS'} // 2,
            PHP_FPM_MIN_SPARE_SERVERS    => $self->{'config'}->{'PHP_FPM_MIN_SPARE_SERVERS'} // 1,
            PHP_FPM_PROCESS_IDLE_TIMEOUT => $self->{'config'}->{'PHP_FPM_PROCESS_IDLE_TIMEOUT'} || '60s',
            PHP_FPM_PROCESS_MANAGER_MODE => $self->{'config'}->{'PHP_FPM_PROCESS_MANAGER_MODE'} || 'ondemand',
            PHP_FPM_START_SERVERS        => $self->{'config'}->{'PHP_FPM_START_SERVERS'} // 1,
            PHP_VERSION                  => $self->{'config'}->{'PHP_VERSION'},
            TMPDIR                       => "$moduleData->{'HOME_DIR'}/phptmp"
        };

        $rs = $self->buildConfFile(
            'fpm/pool.conf', "$self->{'config'}->{'PHP_FPM_POOL_DIR_PATH'}/$phpConfigLevel.conf", $moduleData, $serverData, { cached => 1 }
        );
    } elsif ( ( $moduleData->{'PHP_SUPPORT'} ne 'yes'
        || ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_user' && $moduleData->{'DOMAIN_TYPE'} ne 'dmn' )
        || ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_domain' && $moduleData->{'DOMAIN_TYPE'} !~ /^(?:dmn|als)$/ )
        || ( $self->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_site' ) )
        && -f "$self->{'config'}->{'PHP_FPM_POOL_DIR_PATH'}/$moduleData->{'DOMAIN_NAME'}.conf"
    ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'PHP_FPM_POOL_DIR_PATH'}/$moduleData->{'DOMAIN_NAME'}.conf" )->delFile();
        $self->{'reload'} ||= 1;
    }

    $rs ||= $self->{'eventManager'}->trigger( 'afterPhpFpmSapiBuildConf', $moduleData );
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    if ( -f "$self->{'cfgDir'}/php.old.data" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/php.old.data" )->delFile();
        return $rs if $rs;
    }

    0;
}

=back

=head1 EVENT LISTENERS

=over 4

=item beforeApache2BuildConfFile( $phpServer, \$cfgTpl, $filename, \$trgFile, \%moduleData, \%apache2ServerData, \%apache2ServerConfig, $parameters )

 Event listener that inject PHP configuration in Apache2 vhosts

 Param scalar $phpServer Servers::php::Abstract instance
 Param scalar \$scalar Reference to Apache2 vhost content
 Param string $filename Apache2 template name
 Param scalar \$trgFile Target file path
 Param hashref \%moduleData Data as provided by Alias|Domain|Subdomain|SubAlias modules
 Param hashref \%apache2ServerData Apache2 server data
 Param hashref \%apache2ServerConfig Apache2 server data
 Param hashref \%parameters OPTIONAL Parameters:
  - user  : File owner (default: root)
  - group : File group (default: root
  - mode  : File mode (default: 0644)
  - cached : Whether or not loaded file must be cached in memory
 Return int 0 on success, other on failure

=cut

sub beforeApache2BuildConfFile
{
    my ($phpServer, $cfgTpl, $filename, $trgFile, $moduleData, $apache2ServerData, $apache2ServerConfig, $parameters) = @_;

    return 0 unless $filename eq 'domain.tpl' && grep( $_ eq $apache2ServerData->{'VHOST_TYPE'}, ( 'domain', 'domain_ssl' ) );

    $phpServer->{'eventManager'}->trigger(
        'beforePhpApache2BuildConfFile', $phpServer, $cfgTpl, $filename, $trgFile, $moduleData, $apache2ServerData, $apache2ServerConfig, $parameters
    );

    debug( sprintf( 'Injecting PHP configuration in Apache2 vhost for the %s domain', $moduleData->{'DOMAIN_NAME'} ));

    my ($phpConfigLevel, $emailDomain);
    if ( $phpServer->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_user' ) {
        $phpConfigLevel = $moduleData->{'ROOT_DOMAIN_NAME'};
        $emailDomain = $moduleData->{'ROOT_DOMAIN_NAME'};
    } elsif ( $phpServer->{'config'}->{'PHP_CONFIG_LEVEL'} eq 'per_domain' ) {
        $phpConfigLevel = $moduleData->{'PARENT_DOMAIN_NAME'};
        $emailDomain = $moduleData->{'DOMAIN_NAME'};
    } else {
        $phpConfigLevel = $moduleData->{'DOMAIN_NAME'};
        $emailDomain = $moduleData->{'DOMAIN_NAME'};
    }

    if ( $phpServer->{'config'}->{'PHP_SAPI'} eq 'apache2handler' ) {
        if ( $moduleData->{'FORWARD'} eq 'no' && $moduleData->{'PHP_SUPPORT'} eq 'yes' ) {
            @{$apache2ServerData}{qw/ EMAIL_DOMAIN TMPDIR /} = ( $emailDomain, $moduleData->{'HOME_DIR'} . '/phptmp' );

            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        # SECTION php_apache2handler BEGIN.
        AllowOverride All
        DirectoryIndex index.php
        php_admin_value open_basedir "{HOME_DIR}/:{PEAR_DIR}/:dev/random:/dev/urandom"
        php_admin_value upload_tmp_dir "{TMPDIR}"
        php_admin_value session.save_path "{TMPDIR}"
        php_admin_value soap.wsdl_cache_dir "{TMPDIR}"
        php_admin_value sendmail_path "/usr/sbin/sendmail -t -i -f webmaster\@{EMAIL_DOMAIN}"
        php_admin_value max_execution_time {MAX_EXECUTION_TIME}
        php_admin_value max_input_time {MAX_INPUT_TIME}
        php_admin_value memory_limit "{MEMORY_LIMIT}M"
        php_flag display_errors {DISPLAY_ERRORS}
        php_admin_value post_max_size "{POST_MAX_SIZE}M"
        php_admin_value upload_max_filesize "{UPLOAD_MAX_FILESIZE}M"
        php_admin_flag allow_url_fopen {ALLOW_URL_FOPEN}
        # SECTION php_apache2handler END.
        # SECTION document root addons END.
EOF
        } else {
            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
      # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
      AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
        Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    RemoveHandler .php .php3 .php4 .php5 .php7 .pht .phtml
    php_admin_flag engine off
    # SECTION addons END.
EOF
        }
    } elsif ( $phpServer->{'config'}->{'PHP_SAPI'} eq 'cgi' ) {
        if ( $moduleData->{'FORWARD'} eq 'no' && $moduleData->{'PHP_SUPPORT'} eq 'yes' ) {
            @{$apache2ServerData}{
                qw/ PHP_CONFIG_LEVEL PHP_FCGI_STARTER_DIR PHP_FCGID_BUSY_TIMEOUT PHP_FCGID_MIN_PROCESSES_PER_CLASS PHP_FCGID_MAX_PROCESS_PER_CLASS /
            } = (
                $phpConfigLevel,
                $phpServer->{'config'}->{'PHP_FCGI_STARTER_DIR'},
                $moduleData->{'MAX_EXECUTION_TIME'}+10,
                $phpServer->{'config'}->{'PHP_FCGID_MIN_PROCESSES_PER_CLASS'} || 0,
                $phpServer->{'config'}->{'PHP_FCGID_MAX_PROCESS_PER_CLASS'} || 6
            );

            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        # SECTION php_cgi BEGIN.
        AllowOverride All
        DirectoryIndex index.php
        Options +ExecCGI
        FCGIWrapper {PHP_FCGI_STARTER_DIR}/{PHP_CONFIG_LEVEL}/php-fcgi-starter
        # SECTION php_cgi END.
        # SECTION document root addons END.
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    FcgiBusyTimeout {PHP_FCGID_BUSY_TIMEOUT}
    FcgidMinProcessesPerClass {PHP_FCGID_MIN_PROCESSES_PER_CLASS}
    FcgidMaxProcessesPerClass {PHP_FCGID_MAX_PROCESS_PER_CLASS}
    # SECTION addons END.
EOF
        } else {
            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
          Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    RemoveHandler .php .php3 .php4 .php5 .php7 .pht .phtml
    # SECTION addons END.
EOF
        }
    } elsif ( $phpServer->{'config'}->{'PHP_SAPI'} eq 'fpm' ) {
        if ( $moduleData->{'FORWARD'} eq 'no' && $moduleData->{'PHP_SUPPORT'} eq 'yes' ) {
            @{$apache2ServerData}{
                qw/ PHP_CONFIG_LEVEL PROXY_FCGI_PATH PROXY_FCGI_URL PROXY_FCGI_RETRY PROXY_FCGI_CONNECTION_TIMEOUT PROXY_FCGI_TIMEOUT /
            } = (
                $phpConfigLevel,
                ( $phpServer->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'uds'
                    ? "unix:/run/php/php$phpServer->{'config'}->{'PHP_VERSION'}-fpm-{PHP_CONFIG_LEVEL}.sock|" : ''
                ),
                ( 'fcgi://' . ( $phpServer->{'config'}->{'PHP_FPM_LISTEN_MODE'} eq 'uds'
                    ? '{PHP_CONFIG_LEVEL}'
                    : '127.0.0.1:' . ( $phpServer->{'config'}->{'PHP_FPM_LISTEN_PORT_START'}+$moduleData->{'PHP_FPM_LISTEN_PORT'} ) )
                ),
                0,
                5,
                $moduleData->{'MAX_EXECUTION_TIME'}+10
            );

            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        # SECTION php_fpm BEGIN.
        AllowOverride All
        DirectoryIndex index.php
        <If "%{REQUEST_FILENAME} =~ /\.ph(?:p[3457]?|t|tml)\$/ && -f %{REQUEST_FILENAME}">
            SetEnvIfNoCase ^Authorization\$ "(.+)" HTTP_AUTHORIZATION=\$1
            SetHandler proxy:{PROXY_FCGI_URL}
        </If>
        # SECTION php_fpm END.
        # SECTION document root addons END.
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    # SECTION php_fpm_proxy BEGIN.
    <Proxy "{PROXY_FCGI_PATH}{PROXY_FCGI_URL}" retry={PROXY_FCGI_RETRY}>
        ProxySet connectiontimeout={PROXY_FCGI_CONNECTION_TIMEOUT} timeout={PROXY_FCGI_TIMEOUT}
    </Proxy>
    # SECTION php_fpm_proxy END.
    # SECTION addons END.
EOF
        } else {
            replaceBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", <<"EOF", $cfgTpl );
        # SECTION document root addons BEGIN.
@{[ getBlocByRef( "# SECTION document root addons BEGIN.\n", "# SECTION document root addons END.\n", $cfgTpl ) ]}
        AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
          Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
EOF
            replaceBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", <<"EOF", $cfgTpl );
    # SECTION addons BEGIN.
@{[ getBlocByRef( "# SECTION addons BEGIN.\n", "# SECTION addons END.\n", $cfgTpl ) ]}
    RemoveHandler .php .php3 .php4 .php5 .php7 .pht .phtml
    # SECTION addons END.
EOF
        }
    } else {
        error( 'Unknown PHP SAPI' );
        return 1;
    }

    $phpServer->{'eventManager'}->trigger(
        'afterPhpApache2BuildConfFile', $phpServer, $cfgTpl, $filename, $trgFile, $moduleData, $apache2ServerData, $apache2ServerConfig, $parameters
    );
}

=item afterApache2AddFiles( \%moduleData )

 Event listener that create PHP (phptmp) directory in customer Web folders

 Param hashref \%moduleData Data as provided by Alias|Domain|Subdomain|SubAlias modules
 Return int 0 on success, other on failure

=cut

sub afterApache2AddFiles
{

    my (undef, $moduleData) = @_;

    return 0 unless $moduleData->{'DOMAIN_TYPE'} eq 'dmn';

    eval {
        iMSCP::Dir->new( dirname => "$moduleData->{'WEB_DIR'}/phptmp" )->make( {
            user  => $moduleData->{'USER'},
            group => $moduleData->{'GROUP'},
            mode  => 0750
        } )
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
