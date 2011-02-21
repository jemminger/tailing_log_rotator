require 'test_helper'
require 'tempfile'

class TailingLogRotatorTest < ActiveSupport::TestCase

  test 'should leave last N lines' do
    with_sample_log(50) do |sample_log_path|
      lines = File.open(sample_log_path, 'r').readlines
      assert_equal "Line 1\n", lines.first

      results = TailingLogRotator.rotate(sample_log_path, 10)

      lines = File.open(sample_log_path, 'r').readlines
      assert_equal "Line 41\n", lines.first
      assert_match /HUP'ed +\[nothing\]/, results
    end
  end

  test 'should leave last N lines with HUP' do
    with_sample_log(50) do |sample_log_path|
      lines = File.open(sample_log_path, 'r').readlines
      assert_equal "Line 1\n", lines.first

      results = TailingLogRotator.rotate(sample_log_path, 10, :hup => 'syslogd')

      lines = File.open(sample_log_path, 'r').readlines
      assert_equal "Line 41\n", lines.first
      assert_match /HUP'ed +syslogd/, results
    end
  end

  test 'should unrotate' do
    begin
      `echo current_log > /tmp/current_log`
      `echo old_log > /tmp/old_log.20110102_010203 && gzip /tmp/old_log.20110102_010203`
      TailingLogRotator.restore('/tmp/old_log.20110102_010203.gz', '/tmp/current_log')
      lines = File.open('/tmp/current_log', 'r').readlines
      assert_equal "old_log\n", lines.first

    ensure
      Dir['/tmp/current_log*'].each{|path| FileUtils.rm_f(path)}
      Dir['/tmp/old_log*'].each{|path| FileUtils.rm_f(path)}
    end
  end

  protected

  def with_sample_log(lines)
    file = Tempfile.new('tailing_log_rotator_sample.log')
    1.upto(lines){|n| file.write("Line #{n}\n")}
    file.flush

    yield file.path

    Dir["#{file.path}.*"].each{|path| FileUtils.rm_f(path)}
    file.close
    file.unlink
  end

end
