# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

required_plugins = %w( vagrant-hostsupdater )
required_plugins.each do |plugin|
    exec "vagrant plugin install #{plugin};vagrant #{ARGV.join(" ")}" unless Vagrant.has_plugin? plugin || ARGV[0] == 'plugin'
end

module OS
    def OS.windows?
        (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end
end

@docker_network = 'vagrant_nw'
@hostname = 'dev.secretsantaorganizer.com'
@provisioning_dir = '/vagrant/provisioning/docker'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.define :secretsanta do |secretsanta_config|
        secretsanta_config.vm.box = "Intracto/Debian10"

        secretsanta_config.vm.hostname = @hostname
        secretsanta_config.hostsupdater.aliases = [
            "mails.#{@hostname}",
            "phpmyadmin.#{@hostname}",
            "traefik.#{@hostname}"
        ]

        secretsanta_config.vm.provider "virtualbox" do |v|
            # show a display for easy debugging
            v.gui = false

            # RAM size
            v.memory = 2048

            # CPUs
            v.cpus = 2

            # Allow symlinks on the shared folder
            v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
        end

        # Shared folder over NFS unless Windows
        if OS.windows?
            secretsanta_config.vm.synced_folder ".", "/vagrant"
        else
            secretsanta_config.vm.synced_folder ".", "/vagrant", type: "nfs", mount_options: ['rw', 'vers=3', 'udp', 'fsc', 'nolock', 'actimeo=2']
        end

        secretsanta_config.vm.network "private_network", ip: "192.168.33.50"

        # Install custom scripts
        secretsanta_config.vm.provision :shell, inline: "ln -sf /vagrant/provisioning/scripts/* /usr/local/bin/"

        # Docker provisioning
        secretsanta_config.vm.provision "docker" do |d|

            d.post_install_provision :shell, inline: "docker network list | grep -q #{@docker_network} || docker network create #{@docker_network}"

            d.run "traefik", image: "traefik:2.2",
            args: %W[
                -v '/var/run/docker.sock:/var/run/docker.sock:ro'
                -v '#{@provisioning_dir}/traefik/configuration:/configuration:ro'
                -v '#{@provisioning_dir}/certs:/etc/ssl/secretsanta:ro'
                --env-file '#{@provisioning_dir}/traefik/env.list'

                --network #{@docker_network}

                --label 'treafik.docker.network=#{@docker_network}'
                --label 'traefik.http.routers.traefik.rule=Host(`traefik.#{@hostname}`)'
                --label 'traefik.http.routers.traefik.service=api@internal'
                --label 'traefik.http.routers.traefik.entrypoints=https'
                --label 'traefik.http.routers.traefik.tls=true'

                -p 80:80
                -p 443:443
            ].join(' ')

            d.build_image "/vagrant/provisioning/docker/app", args: "-t='app'"
            d.run "app", args: %W[
                -v '#{@provisioning_dir}/app/apache/sites:/etc/apache2/sites-enabled:ro'
                -v '/vagrant:/var/www/html'
                -v '/dev/shm/app/log:/var/log/identityserver'
                -v '/dev/shm/app/cache:/var/cache/identityserver'

                --network #{@docker_network}

                --label 'traefik.http.routers.app_http.rule=Host(`#{@hostname}`)'
                --label 'traefik.http.routers.app_http.entrypoints=http'

                --label 'traefik.http.routers.app_https.rule=Host(`#{@hostname}`)'
                --label 'traefik.http.routers.app_https.entrypoints=https'
                --label 'traefik.http.routers.app_https.tls=true'
            ].join(' ')

            d.run "mysql", image: "mysql:5.6",
            args: %W[
                --network #{@docker_network}
                -v '/home/vagrant/mysql/data:/var/lib/mysql'
                --env-file #{@provisioning_dir}/mysql/env.list
                -p 3306:3306
            ].join(' ')

            d.run "phpmyadmin", image: "phpmyadmin/phpmyadmin:5.0",
            args: %W[
                --network #{@docker_network}
                -e PMA_ABSOLUTE_URI=phpmyadmin.#{@hostname}
                --env-file #{@provisioning_dir}/phpmyadmin/env.list
                --label 'traefik.http.routers.mailhog.rule=Host(`phpmyadmin.#{@hostname}`)'
                --label 'traefik.http.routers.mailhog.entrypoints=https'
                --label 'traefik.http.routers.mailhog.tls=true'
            ].join(' ')

            d.run "mailhog", image: "mailhog/mailhog:latest",
            args: %W[
                --network #{@docker_network}
                --label 'traefik.http.routers.mailhog.rule=Host(`mails.#{@hostname}`)'
                --label 'traefik.http.routers.mailhog.entrypoints=https'
                --label 'traefik.http.routers.mailhog.tls=true'
                --label 'traefik.http.services.mailhog.loadbalancer.server.port=8025'
            ].join(' ')
        end

        # Install the project's dependencies
        secretsanta_config.vm.provision :shell, inline: "docker exec -i app composer install"

        # After a Vagrant reload, some containers fail to start due to our NFS mount not being fully initialized.
        # We should be able to make the docker systemd service depend on the NFS service/mounts, but I haven't yet
        # figured out how to make that work reliably.
        # So, in the meantime we'll have to make do with this simple workaround:
        secretsanta_config.vm.provision "shell", inline: "sudo systemctl restart docker", run: "always"
    end
end
