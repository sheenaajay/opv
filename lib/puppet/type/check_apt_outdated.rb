# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'check_apt_outdated',
  docs: <<-EOS,
@summary Check for freshness on apt repo info.
@example
check_apt_outdated { 'apt':
  allowed_pkgcache_age_days => 2,
  allowed_mirror_age_days => 7,
}
EOS
  features: [],
  attributes: {
    name: {
      type: 'StringPattern[/^apt$/]',
      desc: 'Always has to be "apt".',
      behaviour: :namevar,
    },
    allowed_pkgcache_age_days: {
      type: 'Number',
      desc: <<~DESC,
How old the apt package cache may be in days, before sounding an alarm.

This parameter looks at the `/var/cache/apt/pkgcache.bin` to determine freshness.

> Note that `apt update` ignores most download errors when rebuilding this file.
DESC
      behaviour: :parameter,
      defaultto: '1.1',
    },
    allowed_mirror_age_days: {
      type: 'Number',
      desc: <<~DESC,
How old the apt repo metadata may be in days, before sounding an alarm.

This parameter looks at the age of files in `/var/lib/apt/lists` to determine freshness.

> Note that `apt update` uses the mirror\'s last modified timestamp on these files.',
DESC
      behaviour: :parameter,
      defaultto: '1.1',
    }
  },
)
