require 'capistrano/scm/base'

module Capistrano
  module SCM

    # An SCM module for using subversion as your source control tool.
    # This module unifies the idea that the subversion repository can be
    # either remote or local, and if remote there maybe a different URL
    # for accessing it from the local machine and the remote machine.
    #
    # to use:
    #   set :scm, :local_subversion_rsync
    #
    # This module accepts a <tt>:remote_svn</tt> configuration variable,
    # which (if specified) will be used as the full path to the svn
    # executable on the remote machine:
    #
    #   set :remote_svn, "/usr/local/bin/svn"
    #
    # This module accepts a <tt>:local_svn</tt> configuration variable,
    # which (if specified) will be used as the full path to the svn
    # executable on the local machine:
    #
    #   set :local_svn, "/usr/local/bin/svn"
    #
    # This module accepts a <tt>:repository_is_not_reachable_from_remote</tt> configuration variable,
    # which (if specified) and set to true will only access the subversion repository from the local machine
    #
    #   set :repository_is_not_reachable_from_remote, true
    #
    # This module accepts a <tt>:local_repository_path</tt> configuration variable,
    # which (if specified) is used to access the repository from the local machine if
    # not set it will be the same as  <tt>:repository</tt>
    #
    #   set :local_repository_path, "svn+ssh://host/restofpath/"
    #
    # If used in repository_is_not_reachable_from_remote mode then the default
    # will write some temporary files and directories to /tmp, if this is not available
    # then the <tt>:tmpdir_local</tt> and  <tt>:tmpdir_remote</tt> variables should be
    # set to a safe directory where temp files and directories can be written
    #
    #   set :tmpdir_local, "/usr/tmp"
    #   set :tmpdir_remote, "/home/user/tmp"
    #
    # alternatively if <tt>:use_rsync</tt> is set it will do an svn update to a local directory
    # <tt>:local_rsync_cache</tt>, then rsync to the remote servers into directory <tt>:remote_rsync_cache</tt>
    # then copy that to the distribution directory.
    #
    #   set :use_rsync, true
    #   set :local_rsync_cache, "/home/user/projects/aproject/cache"
    #   set :remote_rsync_cache, "/var/www/webapp/cache"
    #   set :rsync_username, "ausername"
    #
    # rsync may be passed an array of things to exclude, see --exclude in the rsync man
    #
    #   set :rsync_excludes, ["*.bak", "*.log"]
    #
    # Note you must do a svn checkout to local_rsync_cache at least once before this will work,
    # and remote_rsync_cache must exist on the server
    #
    class LocalSubversionRsync < Base

      # Return an integer identifying the last known revision in the svn
      # repository. (This integer is currently the revision number.)
      def latest_revision
        @latest_revision ||= begin
          configuration.logger.debug "querying latest revision..."
          match = svn_log(rep_path).scan(/r(\d+)/).first or
          raise "Could not determine latest revision"
          match.first
        end
      end

      # Return a string containing the diff between the two revisions. +from+
      # and +to+ may be in any format that svn recognizes as a valid revision
      # identifier. If +from+ is +nil+, it defaults to the last deployed
      # revision. If +to+ is +nil+, it defaults to HEAD.
      def diff(actor, from=nil, to=nil)
        from ||= current_revision(actor)
        to ||= "HEAD"
        `#{svn} diff #{authorization} #{rep_path}@#{from} #{path}@#{to}`
      end

      # Return the number of the revision currently deployed.
      def current_revision(actor)
        latest = actor.releases.last
        grep = %(grep " #{latest}$" #{configuration.deploy_to}/revisions.log)
        result = ""
        actor.run(grep, :once => true) do |ch, str, out|
          result << out if str == :out
          raise "could not determine current revision" if str == :err
        end

        date, time, user, rev, dir = result.split
        raise "current revision not found in revisions.log" unless dir == latest

        rev.to_i
      end

      # Check out (on all servers associated with the current task) the latest
      # revision. If the subversion repository is accessible from the remote machine
      # Uses the given actor instance to execute the command. If
      # svn asks for a password this will automatically provide it (assuming
      # the requested password is the same as the password for logging into the
      # remote server.)
      def checkout(actor)
        username = authorization
        if configuration[:repository_is_not_reachable_from_remote]
          if configuration[:use_rsync]
            do_local_checkout_and_rsync(username, actor)
          else
            do_local_checkout_and_send(username, actor)
          end
        else
          op = configuration[:checkout] || "co"
          command = "#{svn(true)} #{op} #{username} -q -r#{configuration.revision} #{configuration.repository} #{actor.release_path} &&"
          run_checkout(actor, command, &svn_stream_handler(actor))
        end
      end

      # Update the current release in-place. This assumes that the original
      # deployment was made using checkout, and not something like export.
      def update(actor)
        unless configuration[:repository_is_not_reachable_from_remote]
          command = "cd #{actor.current_path} && #{svn(true)} up -q &&"
          run_update(actor, command, &svn_stream_handler(actor))
        else
          raise "#{self.class} doesn't support update(actor)"
        end
      end

      private

      def authorization
        username = configuration[:svn_username] ? "--username #{configuration[:svn_username]}" : ""
        password = configuration[:svn_password] ? "--password #{configuration[:svn_password]}" : ""
        "#{username} #{password}"
      end

      def rep_path
        configuration[:local_repository_path] || configuration[:repository]
      end

      # returns a different incantation for running svn depending on whether it is running locally or remotely
      def svn(on_remote= false)
        s= nil
        if on_remote
          s=  configuration[:remote_svn]
        else
          s= configuration[:local_svn]
        end
        s || configuration[:svn] || "svn"
      end

      def svn_log(path)
        `#{svn} log #{authorization} -q --limit 1 #{path}`
      end


      def svn_password
        configuration[:svn_password] || configuration[:password]
      end

      def svn_passphrase
        configuration[:svn_passphrase] || svn_password
      end

      def svn_stream_handler(actor)
        Proc.new do |ch, stream, out|
          prefix = "#{stream} :: #{ch[:host]}"
          actor.logger.info out, prefix
          if out =~ /\bpassword.*:/i
            actor.logger.info "subversion is asking for a password", prefix
            ch.send_data "#{svn_password}\n"
          elsif out =~ %r{\(yes/no\)}
            actor.logger.info "subversion is asking whether to connect or not",
            prefix
            ch.send_data "yes\n"
          elsif out =~ %r{passphrase}i
            message = "subversion needs your key's passphrase"
            actor.logger.info message, prefix
            ch.send_data "#{svn_passphrase}\n"
          elsif out =~ %r{The entry \'(\w+)\' is no longer a directory}
            message = "subversion can't update because directory '#{$1}' was replaced. Please add it to svn:ignore."
            actor.logger.info message, prefix
            raise message
          elsif out =~ %r{accept \(t\)emporarily}
            message = "accepting certificate temporarily"
            actor.logger.info message, prefix
            ch.send_data "t\n"
          end
        end
      end

      def run_remote(actor, guts)
        directory = File.basename(configuration.release_path)

        command = <<-STR
          if [[ ! -d #{configuration.release_path} ]]; then
            #{guts}
            #{logging_commands(directory)}
          fi
        STR
        actor.run(command)
      end

      # checkout from the local machine
      # tar up results
      # send to remote machine(s)
      # unpack into checkout directory
      def do_local_checkout_and_send(username, actor)
        temp_file= "CAP_TEMP_#{Time.now.to_f}"
        tmpdir_local= configuration[:tmpdir_local] || "/tmp"
        temp_dest_local= File.join(tmpdir_local, temp_file)
        tmpdir_remote= configuration[:tmpdir_remote] || "/tmp"
        temp_dest_remote= File.join(tmpdir_remote, temp_file)
        temp_tar_file_local= File.join(tmpdir_local, "#{temp_file}.tar.gz")
        temp_tar_file_remote= File.join(tmpdir_remote, "#{temp_file}.tar.gz")

        configuration.logger.debug "local executing: #{svn} export #{username}  -q -r#{configuration[:revision]} #{rep_path} #{temp_dest_local}"
        configuration.logger.debug "local creating tar file: #{temp_tar_file_local}"

        # always use export in this case as update will never be possible
        run_local(
          "#{svn} export #{username}  -q -r#{configuration[:revision]} #{rep_path} #{temp_dest_local} && " +
          "tar -C #{temp_dest_local} -c -z -f #{temp_tar_file_local} . && " +
          "rm -rf #{temp_dest_local}"
        )

        # send the tar file to the remote machine(s)
        configuration.logger.debug "sending tar file: #{temp_tar_file_local} to remote #{temp_tar_file_remote}"
        actor.put(read_local_file(temp_tar_file_local), temp_tar_file_remote)

        run_local("rm #{temp_tar_file_local}")

        # unpack the tar file on the remote machine as if it has been checked out there
        cmd="mkdir -p #{actor.release_path} && " +
            "tar -C #{actor.release_path} -x -z -f #{temp_tar_file_remote} && " +
            "rm -f #{temp_tar_file_remote} && "
        run_remote(actor, cmd)
      end

      # update on the local machine from local svn
      # rsync with remote servers
      def do_local_checkout_and_rsync(svn_username, actor)
        rsync_username = configuration[:rsync_username] ? "#{configuration[:rsync_username]}@" : ""
        local_rsync_cache= configuration[:local_rsync_cache]
        remote_rsync_cache= configuration[:remote_rsync_cache]
        if local_rsync_cache.nil? || remote_rsync_cache.nil?
          throw "to use rsync local_rsync_cache and remote_rsync_cache must be set"
        end

        configuration.logger.debug "local executing: #{svn} update #{svn_username}  -q -r#{configuration[:revision]} #{local_rsync_cache}"

        # update the local svn cache
        run_local(
          "#{svn} update #{svn_username} -q -r#{configuration[:revision]} #{local_rsync_cache}"
        )

        # rsync with the remote machine(s)
        rcmd = 'rsync '
        # add rsync options
        %w{
          archive
          compress
          copy-links
          cvs-exclude
          delete-after
          no-blocking-io
          stats
        }.each { | opt | rcmd << "--#{opt} " }

        # excluded files and directories
        excludes= configuration[:rsync_excludes] || []
        excludes.each { |e| rcmd << " --exclude \"#{e}\" " }

        # for each server in current task
        actor.current_task.servers.each do |server|
          configuration.logger.debug "RSyncing deployment cache for #{server}"
          run_local("#{rcmd} -e ssh #{local_rsync_cache}/ #{rsync_username}#{server}:#{remote_rsync_cache}/")
        end

        # copy the remote_rsync_cache on the remote machine as if it has been checked out there
        cmd="cp -a #{remote_rsync_cache}/ #{actor.release_path} && "
        run_remote(actor, cmd)
      end

      # extracted so we can test
      def run_local(cmd)
        system(cmd)
      end

      def read_local_file(fn)
        File.read(fn)
      end

    end
  end
end
