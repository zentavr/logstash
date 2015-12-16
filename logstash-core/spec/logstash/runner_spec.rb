# encoding: utf-8
require "spec_helper"
require "logstash/runner"
require "stud/task"
require "stud/trap"

class NullRunner
  def run(args); end
end

describe LogStash::Runner do

  subject { LogStash::Runner }
  let(:channel) { Cabin::Channel.new }

  before :each do
    allow(Cabin::Channel).to receive(:get).with(LogStash).and_return(channel)
  end

  describe "argument parsing" do
    subject { LogStash::Runner.new("") }
    context "when -e is given" do

      let(:args) { ["-e", "input {} output {}"] }
      let(:agent) { double("agent") }
      let(:agent_logger) { double("agent logger") }

      before do
        allow(agent).to receive(:logger=).with(anything)
        allow(agent).to receive(:shutdown)
        allow(agent).to receive(:register_pipeline)
      end

      it "should execute the agent" do
        expect(subject).to receive(:create_agent).and_return(agent)
        expect(agent).to receive(:execute).once
        subject.run(args)
      end
    end

    context "with no arguments" do
      let(:args) { [] }
      it "should show help" do
        expect($stderr).to receive(:puts).once
        expect(subject).to receive(:signal_usage_error).once.and_call_original
        expect(subject).to receive(:show_short_help).once
        subject.run(args)
      end
    end
  end

  context "--pluginpath" do
    subject { LogStash::Runner.new("") }
    let(:single_path) { "/some/path" }
    let(:multiple_paths) { ["/some/path1", "/some/path2"] }

    it "should add single valid dir path to the environment" do
      expect(File).to receive(:directory?).and_return(true)
      expect(LogStash::Environment).to receive(:add_plugin_path).with(single_path)
      subject.configure_plugin_paths(single_path)
    end

    it "should fail with single invalid dir path" do
      expect(File).to receive(:directory?).and_return(false)
      expect(LogStash::Environment).not_to receive(:add_plugin_path)
      expect{subject.configure_plugin_paths(single_path)}.to raise_error(Clamp::UsageError)
    end

    it "should add multiple valid dir path to the environment" do
      expect(File).to receive(:directory?).exactly(multiple_paths.size).times.and_return(true)
      multiple_paths.each{|path| expect(LogStash::Environment).to receive(:add_plugin_path).with(path)}
      subject.configure_plugin_paths(multiple_paths)
    end
  end

  context "--auto-reload" do
    subject { LogStash::Runner.new("") }
    context "when -f is not given" do

      let(:args) { ["-r", "-e", "input {} output {}"] }

      it "should exit immediately" do
        expect(subject).to receive(:signal_usage_error).and_call_original
        expect(subject).to receive(:show_short_help)
        expect(subject.run(args)).to eq(1)
      end
    end
  end

  describe "pipeline settings" do
    let(:pipeline_string) { "input { stdin {} } output { stdout {} }" }
    let(:main_pipeline_settings) { { :pipeline_id => "main" } }
    let(:pipeline) { double("pipeline") }

    before(:each) do
      task = Stud::Task.new { 1 }
      allow(pipeline).to receive(:run).and_return(task)
      allow(pipeline).to receive(:shutdown)
    end

    context "when :pipeline_workers is not defined by the user" do
      it "should not pass the value to the pipeline" do
        expect(LogStash::Pipeline).to receive(:new).once.with(pipeline_string, hash_excluding(:pipeline_workers)).and_return(pipeline)
        args = ["-e", pipeline_string]
        subject.run("bin/logstash", args)
      end
    end

    context "when :pipeline_workers is defined by the user" do
      it "should pass the value to the pipeline" do
        main_pipeline_settings[:pipeline_workers] = 2
        expect(LogStash::Pipeline).to receive(:new).with(pipeline_string, hash_including(main_pipeline_settings)).and_return(pipeline)
        args = ["-w", "2", "-e", pipeline_string]
        subject.run("bin/logstash", args)
      end
    end
  end
end
