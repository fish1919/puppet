#! /usr/bin/env ruby -S rspec
require 'spec_helper'

require 'puppet/reports'
require 'time'
require 'pathname'
require 'tempfile'
require 'fileutils'

processor = Puppet::Reports.report(:store)

describe processor do
  describe "#process" do
    include PuppetSpec::Files
    before :each do
      Puppet[:reportdir] = File.join(tmpdir('reports'), 'reports')
      @report = YAML.load_file(File.join(PuppetSpec::FIXTURE_DIR, 'yaml/report2.6.x.yaml')).extend processor
    end

    it "should create a report directory for the client if one doesn't exist" do
      @report.process

      File.should be_directory(File.join(Puppet[:reportdir], @report.host))
    end

    it "should write the report to the file in YAML" do
      Time.stubs(:now).returns(Time.parse("2011-01-06 12:00:00 UTC"))
      @report.process

      File.read(File.join(Puppet[:reportdir], @report.host, "201101061200.yaml")).should == @report.to_yaml
    end

    it "should write to the report directory in the correct sequence" do
      # By doing things in this sequence we should protect against race
      # conditions
      Time.stubs(:now).returns(Time.parse("2011-01-06 12:00:00 UTC"))
      writeseq = sequence("write")
      file = mock "file"
      Tempfile.expects(:new).in_sequence(writeseq).returns(file)
      file.expects(:chmod).in_sequence(writeseq).with(0640)
      file.expects(:print).with(@report.to_yaml).in_sequence(writeseq)
      file.expects(:close).in_sequence(writeseq)
      file.stubs(:path).returns(File.join(Dir.tmpdir, "foo123"))
      FileUtils.expects(:mv).in_sequence(writeseq).with(File.join(Dir.tmpdir, "foo123"), File.join(Puppet[:reportdir], @report.host, "201101061200.yaml"))
      @report.process
    end
  end
end
