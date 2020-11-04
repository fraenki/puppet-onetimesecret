# == Class: onetimesecret::install
#
# Installation
#
class onetimesecret::install {

  # Should we manage the package/archive installation?
  if ( $onetimesecret::manage_package == true ) {

    # We won't be able to build the app without these packages.
    if ( $onetimesecret::manage_additional_packages == true ) {

      # Install dependencies required to build OTS
      package { $onetimesecret::additional_packages:
        ensure  => 'installed',
      }

      # Use foreman as process manager
      package {'installforeman':
        ensure   => 'installed',
        name     => 'foreman',
        provider => 'gem',
        require  => Package[$onetimesecret::additional_packages],
      }

    }

    $version = $onetimesecret::version
    $filename = "${version}.tar.gz"
    $source_url = "${onetimesecret::download_url}/${filename}"

    $archive_target = "${onetimesecret::install_dir}/${filename}"
    $install_target = "${onetimesecret::install_dir}/onetimesecret-${version}"

    # Download and extract the distribution archive.
    archive { $archive_target:
      ensure        => present,
      user          => 'root',
      group         => 0,
      source        => $source_url,
      checksum_type => 'none',
      extract_path  => $onetimesecret::install_dir,
      # Extract files as the user doing the extracting, which is the user
      # that runs Puppet, usually root
      extract_flags => '-x --no-same-owner -f',
      creates       => $install_target,
      extract       => true,
      cleanup       => false,
      require       => [
        Package[$onetimesecret::additional_packages],
      ],
    }

    # Create required runtime directories.
    file {
      [ $onetimesecret::config_dir, $onetimesecret::data_dir,
      $onetimesecret::log_dir, $onetimesecret::pid_dir ]:
        ensure => directory,
        owner  => $onetimesecret::user,
        group  => $onetimesecret::group,
        before => [
          Exec["build ${module_name} version ${version} from source package"],
        ],
    }

    # Build from source
    exec { "build ${module_name} version ${version} from source package":
      cwd         => "${onetimesecret::install_dir}/onetimesecret-${version}",
      command     => "${onetimesecret::bundle_exec} install --deployment --frozen --without=dev",
      path        => $onetimesecret::path,
      user        => 'root',
      refreshonly => true,
      subscribe   => [
        Archive[$archive_target],
      ],
      require     => [
        Archive[$archive_target],
        Package[$onetimesecret::additional_packages]
      ],
    }

    # Change file owner
    exec { 'chown onetimesecret source directory':
      command     => "chown -R ${onetimesecret::user}:${onetimesecret::group} ${install_target}",
      path        => $onetimesecret::path,
      refreshonly => true,
      subscribe   => [
        Exec["build ${module_name} version ${version} from source package"],
      ],
      require     => [
        Exec["build ${module_name} version ${version} from source package"],
      ],
    }

    # Copy required static files to config directory
    exec { "copy ${module_name} static files for version ${version} to ${onetimesecret::config_dir}":
      cwd         => $install_target,
      command     => "cp -Rp etc/locale etc/fortunes ${onetimesecret::config_dir}/",
      path        => $onetimesecret::path,
      refreshonly => true,
      subscribe   => [
        Exec['chown onetimesecret source directory'],
      ],
      require     => [
        Exec['chown onetimesecret source directory'],
      ],
    }

    # Set symlink to current version
    if $onetimesecret::manage_symlink {
      file { $onetimesecret::symlink_name:
        ensure  => link,
        target  => $install_target,
        owner   => $onetimesecret::user,
        group   => $onetimesecret::group,
        require => [
          Exec['chown onetimesecret source directory'],
      ],
      }
    }

  }
}
