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
@aliases = [
   "mails.#{@hostname}",
   "phpmyadmin.#{@hostname}",
   "traefik.#{@hostname}"
]

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.define :secretsanta do |secretsanta_config|
        secretsanta_config.vm.box = "Intracto/Debian10"

        secretsanta_config.vm.hostname = @hostname
        secretsanta_config.hostsupdater.aliases = @aliases

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

        config.trigger.before :up do |trigger|
            trigger.info = "Generating SSL certificates..."
            trigger.run = { path: "vagrant/trigger/generate_certs.sh", args: "#{@hostname} #{@aliases.join(' ')}" }
        end

        # Shared folder over NFS unless Windows
        if OS.windows?
            secretsanta_config.vm.synced_folder ".", "/vagrant"
        else
            secretsanta_config.vm.synced_folder ".", "/vagrant", type: "nfs", mount_options: ['rw', 'vers=3', 'udp', 'fsc', 'nolock', 'actimeo=2']
        end

        secretsanta_config.vm.network "private_network", ip: "192.168.33.50"

        # Install custom scripts
        secretsanta_config.vm.provision :shell, inline: "ln -sf /vagrant/vagrant/bin/* /usr/local/bin/"

        # Docker provisioning
        secretsanta_config.vm.provision "docker" do |d|

            d.post_install_provision :shell, inline: "docker network list | grep -q #{@docker_network} || docker network create #{@docker_network}"

            d.build_image "/vagrant/docker/node", args: "-t='node'"

            d.run "traefik", image: "traefik:2.2",
            args: %W[
                -v '/var/run/docker.sock:/var/run/docker.sock:ro'
                -v '/vagrant/docker/traefik/configuration:/configuration:ro'
                -v '/vagrant/docker/traefik/certs:/etc/ssl/secretsanta:ro'
                --env-file '/vagrant/docker/traefik/env.list'

                --network #{@docker_network}

                --label 'treafik.docker.network=#{@docker_network}'
                --label 'traefik.http.routers.traefik.rule=Host(`traefik.#{@hostname}`)'
                --label 'traefik.http.routers.traefik.service=api@internal'
                --label 'traefik.http.routers.traefik.entrypoints=https'
                --label 'traefik.http.routers.traefik.tls=true'

                --label "traefik.http.routers.https-redirect.entrypoints=http"
                --label "traefik.http.routers.https-redirect.rule=HostRegexp(`{any:.*}`)"
                --label "traefik.http.routers.https-redirect.middlewares=https-redirect"
                --label "traefik.http.middlewares.https-redirect.redirectscheme.scheme=https"

                -p 80:80
                -p 443:443
            ].join(' ')

            d.run "httpd", image: "httpd:2.4-alpine",
            args: %W[
                -v '/vagrant:/usr/local/apache2/htdocs'
                -v '/vagrant/docker/httpd/httpd.conf:/usr/local/apache2/conf/httpd.conf'

                --network #{@docker_network}

                --label 'traefik.http.routers.app_https.rule=Host(`#{@hostname}`)'
                --label 'traefik.http.routers.app_https.entrypoints=https'
                --label 'traefik.http.routers.app_https.tls=true'
            ].join(' ')

            d.build_image "/vagrant", args: "--target development -t='app'"
            d.run "app", args: %W[
                -v '/vagrant/docker/php/conf.d/symfony.dev.ini:/usr/local/etc/php/conf.d/symfony.ini:ro'
                -v '/vagrant:/var/www/html'
                --mount source=applogs,target=/var/log/symfony
                --env-file /vagrant/docker/php/env.list

                --network #{@docker_network}
            ].join(' ')

            d.run "mysql", image: "mysql:5.6",
            args: %W[
                --network #{@docker_network}
                -v '/home/vagrant/mysql/data:/var/lib/mysql'
                --env-file /vagrant/docker/mysql/env.list
                -p 3306:3306
            ].join(' ')

            d.run "phpmyadmin", image: "phpmyadmin/phpmyadmin:5.0",
            args: %W[
                --network #{@docker_network}
                -e PMA_ABSOLUTE_URI=phpmyadmin.#{@hostname}
                --env-file /vagrant/docker/phpmyadmin/env.list
                --label 'traefik.http.routers.pma.rule=Host(`phpmyadmin.#{@hostname}`)'
                --label 'traefik.http.routers.pma.entrypoints=https'
                --label 'traefik.http.routers.pma.tls=true'
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

        # Install the project's dependencies & assets
        secretsanta_config.vm.provision :shell, path: "vagrant/provision/setup_project.sh"

        # After a Vagrant reload, some containers fail to start due to our NFS mount not being fully initialized.
        # We should be able to make the docker systemd service depend on the NFS service/mounts, but I haven't yet
        # figured out how to make that work reliably.
        # So, in the meantime we'll have to make do with this simple workaround:
        secretsanta_config.vm.provision "shell", inline: "sudo systemctl restart docker", run: "always"
    end
end
