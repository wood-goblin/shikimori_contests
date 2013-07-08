require 'spec_helper'

describe ContestRound do
  context '#relations' do
    it { should belong_to :contest }
    it { should have_many :votes }
  end

  describe 'states' do
    let(:round) { create :contest_round, contest: create(:contest_with_5_animes, state: 'started') }

    it 'full cycle' do
      round.created?.should be_true

      round.take_votes
      round.start!
      round.started?.should be_true

      round.votes.each { |v| v.state = 'finished' }
      round.finish!
      round.finished?.should be_true
    end

    describe :can_start? do
      subject { round.can_start? }

      context 'no votes' do
        it { should be_false }
      end

      context 'has votes' do
        before { round.take_votes }
        it { should be_true }
      end
    end

    describe :can_finish? do
      subject { round.can_finish? }

      context 'not finished votes' do
        before do
          round.take_votes
          round.start!
        end
        it { should be_false }
      end

      context 'finished votes' do
        before do
          round.take_votes
          round.start!
        end

        context 'all finished' do
          before { round.votes.each { |v| v.state = 'finished' } }
          it { should be_true }
        end

        context 'all can_finish' do
          before { round.votes.each { |v| v.stub(:can_finish?).and_return true } }
          it { should be_true }
        end
      end
    end

    context 'after started' do
      it 'starts today votes' do
        round.take_votes
        round.start!
        round.votes.each do |vote|
          vote.started?.should be_true
        end
      end

      it 'does not start votes in future' do
        round.take_votes
        round.votes.each { |v| v.started_on = Date.tomorrow }
        round.start!

        round.votes.each do |vote|
          vote.started?.should be_false
        end
      end
    end

    context 'before finished' do
      before do
        round.take_votes
        round.start!
        round.votes.each { |v| v.finished_on = Date.yesterday }
      end

      describe 'finishes unfinished votes' do
        before { round.finish! }
        it { round.votes.each { |v| v.finished?.should be_true } }
      end
    end

    context 'after finished' do
      before do
        round.take_votes
        round.start!
        round.votes.each { |v| v.finished_on = Date.yesterday }
      end
      let(:next_round) { create :contest_round }

      it 'starts next round' do
        round.stub(:next_round).and_return(next_round)
        next_round.should_receive(:start!)
        round.finish!
      end

      it 'finishes contest' do
        round.finish!
        round.contest.finished?.should be_true
      end
    end
  end

  describe :fill_votes do
    let(:round) { create :contest_round, contest: create(:contest, votes_per_round: 4, vote_duration: 4) }
    let(:animes) { 1.upto(11).map { create :anime } }

    it 'creates animes/2 votes' do
      expect { round.send :fill_votes, animes, group: ContestRound::W }.to change(ContestVote, :count).by (animes.size.to_f / 2).ceil
    end

    it 'fills left&right correctly' do
      round.send :fill_votes, animes, shuffle: false

      round.votes[0].left_id.should eq animes[0].id
      round.votes[0].right_id.should eq animes[1].id

      round.votes[1].left_id.should eq animes[2].id
      round.votes[1].right_id.should eq animes[3].id

      round.votes[5].left_id.should eq animes[10].id
      round.votes[5].right_id.should be_nil
    end

    describe 'dates' do
      before { round.send :fill_votes, animes, shuffle: false }
      let(:votes_per_round) { round.contest.votes_per_round }

      it 'first of first round' do
        round.votes[0].started_on.should eq round.contest.started_on
        round.votes[0].finished_on.should eq round.contest.started_on + (round.contest.vote_duration-1).days
      end

      it 'last of first round' do
        round.votes[votes_per_round - 1].started_on.should eq round.contest.started_on
        round.votes[votes_per_round - 1].finished_on.should eq round.contest.started_on + (round.contest.vote_duration-1).days
      end

      it 'first of second round' do
        round.votes[votes_per_round].started_on.should eq round.contest.started_on + round.contest.vote_interval.days
        round.votes[votes_per_round].finished_on.should eq round.contest.started_on + (round.contest.vote_interval-1).days + round.contest.vote_duration.days
      end

      context 'additional fill_votes' do
        before do
          @prior_last_vote = round.votes.last
          @prior_count = round.votes.count
          round.send :fill_votes, animes, shuffle: false
        end

        it 'continues from last vote' do
          round.votes[@prior_count].started_on.should eq @prior_last_vote.started_on
        end
      end
    end

    describe :shuffle do
      let(:ordered?) { round.votes[0].left_id == animes[0].id && round.votes[0].right_id == animes[1].id && round.votes[1].left_id == animes[2].id && round.votes[1].right_id == animes[3].id }

      context 'false' do
        before { round.send :fill_votes, animes, shuffle: false }

        it 'fills votes with ordered animes' do
          ordered?.should be_true
        end
      end

      context 'true' do
        before { round.send :fill_votes, animes, shuffle: true }

        it 'fills votes with shuffled animes' do
          ordered?.should be_false
        end
      end
    end
  end

  describe 'advance winner&loser' do
    let(:contest) { create :contest_with_5_animes }
    let(:w1) { contest.rounds[0].votes[0].left }
    let(:w2) { contest.rounds[0].votes[1].left }
    let(:w3) { contest.rounds[0].votes[2].left }
    let(:l1) { contest.rounds[0].votes[0].right }
    let(:l2) { contest.rounds[0].votes[1].right }

    before do
      contest.start!
    end

    context 'I -> II' do
      before do
        1.times { |i| contest.rounds[i].votes.each { |v| v.update_attributes started_on: Date.yesterday, finished_on: Date.yesterday } }
        1.times do
          contest.current_round.reload
          contest.current_round.finish!
        end
      end

      it 'winners&losers' do
        contest.current_round.votes[0].left.should eq w1
        contest.current_round.votes[0].right.should eq w2

        contest.current_round.votes[1].left.should eq w3
        contest.current_round.votes[1].right.should be_nil

        contest.current_round.votes[2].left.should eq l1
        contest.current_round.votes[2].right.should eq l2
      end
    end

    context 'II -> IIa, II -> III' do
      before do
        2.times { |i| contest.rounds[i].votes.each { |v| v.update_attributes started_on: Date.yesterday, finished_on: Date.yesterday } }
        2.times do |i|
          contest.current_round.reload
          contest.current_round.finish!
        end
      end

      it 'winners&losers' do
        contest.current_round.votes[0].left.should eq l1
        contest.current_round.votes[0].right.should eq w2

        contest.current_round.next_round.votes[0].left.should eq w1
        contest.current_round.next_round.votes[0].right.should eq w3
      end
    end

    context 'IIa -> III' do
      before do
        3.times { |i| contest.rounds[i].votes.each { |v| v.update_attributes started_on: Date.yesterday, finished_on: Date.yesterday } }
        3.times do |i|
          contest.current_round.reload
          contest.current_round.finish!
        end
      end

      it 'winners' do
        contest.current_round.votes[1].left.should eq l1
        contest.current_round.votes[1].right.should be_nil
      end
    end

    context 'III -> IIIa, III -> IV' do
      before do
        4.times { |i| contest.rounds[i].votes.each { |v| v.update_attributes started_on: Date.yesterday, finished_on: Date.yesterday } }
        4.times do |i|
          contest.current_round.reload
          contest.current_round.finish!
        end
      end

      it 'winners&losers' do
        contest.current_round.votes[0].left.should eq w3
        contest.current_round.votes[0].right.should eq l1

        contest.current_round.next_round.votes[0].left.should eq w1
        contest.current_round.next_round.votes[0].right.should be_nil
      end
    end

    context 'III -> IV' do
      before do
        5.times { |i| contest.rounds[i].votes.each { |v| v.update_attributes started_on: Date.yesterday, finished_on: Date.yesterday } }
        5.times do |i|
          contest.current_round.reload
          contest.current_round.finish!
        end
      end

      it 'winners' do
        contest.current_round.votes[0].right.should eq w3
      end
    end
  end

  describe :prior_round do
    let(:contest) { create :contest_with_5_animes }
    before { contest.send :build_rounds }

    it 'I' do
      contest.rounds[0].prior_round.should be_nil
    end

    it 'II' do
      contest.rounds[1].prior_round.should eq contest.rounds[0]
    end

    it 'IIa' do
      contest.rounds[2].prior_round.should eq contest.rounds[1]
    end

    it 'III' do
      contest.rounds[3].prior_round.should eq contest.rounds[2]
    end

    it 'IIIa' do
      contest.rounds[4].prior_round.should eq contest.rounds[3]
    end

    it 'IV' do
      contest.rounds[5].prior_round.should eq contest.rounds[4]
    end
  end

  describe :next_round do
    let(:contest) { create :contest_with_5_animes }
    before { contest.send :build_rounds }

    it 'I' do
      contest.rounds[0].next_round.should eq contest.rounds[1]
    end

    it 'II' do
      contest.rounds[1].next_round.should eq contest.rounds[2]
    end

    it 'IIa' do
      contest.rounds[2].next_round.should eq contest.rounds[3]
    end

    it 'III' do
      contest.rounds[3].next_round.should eq contest.rounds[4]
    end

    it 'IIIa' do
      contest.rounds[4].next_round.should eq contest.rounds[5]
    end

    it 'IV' do
      contest.rounds[5].next_round.should eq nil
    end
  end

  describe :take_votes do
    context '19 animes' do
      let(:contest) { create :contest_with_19_animes, votes_per_round: 3 }
      before { contest.send :build_rounds }

      context 'I' do
        let(:round) { contest.rounds.first }
        before { contest.rounds[0..0].each(&:take_votes) }

        it 'should not left last vote for next day' do
          round.votes.map(&:started_on).map(&:to_s).uniq.should have(3).items
        end
      end

      context 'II' do
        let(:round) { contest.rounds[1] }
        before { contest.rounds[0..1].each(&:take_votes) }

        it 'should make the same date grouping as in the first round' do
          round.votes.map(&:started_on).map(&:to_s).uniq.should have(3).items
        end
      end
    end

    context '5 animes' do
      let(:contest) { create :contest_with_5_animes }
      before { contest.send :build_rounds }

      context 'I' do
        let(:round) { contest.rounds.first }
        before { contest.rounds[0..0].each(&:take_votes) }

        it 'valid' do
          round.votes.should have(3).items
          round.votes.each { |vote| vote.group.should eq ContestRound::S }
          round.votes.first.started_on.should eq contest.started_on
          round.votes.first.right_type.should_not be_nil
          round.votes.last.right_type.should be_nil
        end
      end

      context 'II' do
        let(:round) { contest.rounds[1] }
        before { contest.rounds[0..1].each(&:take_votes) }

        it 'valid' do
          round.votes.should have(3).items
          round.votes[0..1].each { |vote| vote.group.should eq ContestRound::W }
          round.votes[2..2].each { |vote| vote.group.should eq ContestRound::L }
          round.votes.first.started_on.should eq (round.prior_round.votes.last.finished_on+contest.vote_interval.days)
          round.votes.first.right_type.should_not be_nil
        end
      end

      context 'IIa' do
        let(:round) { contest.rounds[2] }
        before { contest.rounds[0..2].each(&:take_votes) }

        it 'valid' do
          round.votes.should have(1).item
          round.votes.each { |vote| vote.group.should eq ContestRound::L }
          round.votes.first.started_on.should eq (round.prior_round.votes.last.finished_on+contest.vote_interval.days)
          round.votes.first.right_type.should_not be_nil
        end
      end

      context 'III' do
        let(:round) { contest.rounds[3] }
        before { contest.rounds[0..3].each(&:take_votes) }

        it 'valid' do
          round.votes.should have(2).items
          round.votes.first.group.should eq ContestRound::W
          round.votes.last.group.should eq ContestRound::L
          round.votes.first.started_on.should eq (round.prior_round.votes.last.finished_on+contest.vote_interval.days)
          round.votes.first.right_type.should_not be_nil
        end
      end

      context 'IIIa' do
        let(:round) { contest.rounds[4] }
        before { contest.rounds[0..4].each(&:take_votes) }

        it 'valid' do
          round.votes.should have(1).item
          round.votes.first.group.should eq ContestRound::L
          round.votes.first.right_type.should_not be_nil
        end
      end

      context 'IV' do
        let(:round) { contest.rounds.last }
        before { contest.rounds.each(&:take_votes) }

        it 'valid' do
          round.votes.should have(1).item
          round.votes.first.group.should eq ContestRound::F
          round.votes.first.started_on.should eq (round.prior_round.votes.last.finished_on+contest.vote_interval.days)
          round.votes.first.right_type.should_not be_nil
        end
      end
    end
  end

  describe 'first&last' do
    let(:contest) { create :contest_with_5_animes }
    before { contest.send :build_rounds }

    it 'correct' do
      contest.rounds.first.first?.should be_true
      contest.rounds.first.last?.should be_false

      1.upto(contest.rounds.count - 2) do |index|
        contest.rounds[index].first?.should be_false
        contest.rounds[index].last?.should be_false
      end

      contest.rounds.last.first?.should be_false
      contest.rounds.last.last?.should be_true
    end
  end
end