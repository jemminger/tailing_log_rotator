require 'fileutils'

#
# probably has gaping security holes due to use of "tail", "killall -HUP" and
# "gzip" without sanitization of parameters, so use at your own risk.
#
# *Should* be safe though since YOU should be the one passing the parameters,
# not via user input.
#

# 2M lines of maillog is currently about 3-4 weeks
# so should be OK to run this weekly
# TailingLogRotator.rotate('/var/log/maillog', 2_000_000)
# TailingLogRotator.rotate('/var/spool/mail/root', 0)

class TailingLogRotator

  #
  # Rotates a log file while keeping its last NNN lines in the new log file.
  #
  # TODO:
  #   - allow custom rotated file names (default is .YYYYMMDD_HHMMSS)
  #
  def self.rotate(log_path, lines_to_preserve, options={})
    options = {
      :hup => nil
    }.merge(options)

    if !File.exists?(log_path)
      raise "rotate: Can't find file #{log_path}"
    else
      # write the last NNN lines to a new log
      `tail -n #{lines_to_preserve.to_i} "#{log_path}" > "#{log_path}.new"`

      # move the existing log to datestamped backup
      datestamp = Time.now.utc.strftime("%Y%m%d_%H%M%S")
      FileUtils.mv log_path, "#{log_path}.#{datestamp}"

      # move the new log to normal log
      FileUtils.mv "#{log_path}.new", log_path

      # HUP if necessary
      `killall -HUP #{options[:hup]}` if (options[:hup] && !options[:hup].empty?)

      # compress the backup
      `gzip "#{log_path}.#{datestamp}"`

      "
  Rotated:
    log         #{log_path}
    to          #{log_path}.#{datestamp}
    preserving  #{lines_to_preserve} lines
    HUP'ed      #{(options[:hup] && !options[:hup].empty?) ? options[:hup] : '[nothing]'}
      "
    end
  end

  #
  # restores a previously rotated log file from gzipped_log_path to original_log_path
  #
  def self.restore(gzipped_log_path, original_log_path, options={})
    options = {
      :hup => nil
    }.merge(options)

    if !File.exists?(gzipped_log_path)
      raise "restore: Can't find file #{gzipped_log_path}"
    else
      `gunzip "#{gzipped_log_path}"`
      unzipped_log_path = gzipped_log_path.sub(/\.gz$/, '')
      datestamp = Time.now.utc.strftime("%Y%m%d_%H%M%S")

      # move existing log to backup
      FileUtils.mv original_log_path, "#{original_log_path}.moved_by_restore.#{datestamp}"

      # move the datestamped backup to normal log
      FileUtils.mv unzipped_log_path, original_log_path

      # HUP if necessary
      `killall -HUP #{options[:hup]}` if (options[:hup] && !options[:hup].empty?)

      "
  Restored:
    from                    #{gzipped_log_path}
    to                      #{original_log_path}
    moved existing file to  #{original_log_path}.undone.#{datestamp}
    HUP'ed                  #{(options[:hup] && !options[:hup].empty?) ? options[:hup] : '[nothing]'}
      "
    end
  end

end
