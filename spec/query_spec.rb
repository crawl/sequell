require 'spec_helper'

describe "SQLQuery" do
  context "given a query with an action flag" do
    it "should have the correct query action type" do
      lg('!lg * -tv:<3').action_type.should == "tv"
      lg('!lg * -ttyrec').action_type.should == 'ttyrec'
      lg('!lg *').action_type.should be_nil
    end

    it "should extract the full action flag text" do
      lg('!lg * -tv:<2:>3').action_flag.should == "tv:<2:>3"
      lg('!lg * -ttyrec').action_flag.should == "ttyrec"
      lg('!lg * -log').action_flag.should == "log"
      lg('!lg *').action_flag.should be_nil
    end
  end

  context "given a query with an action flag in a subquery" do
    it "should throw a parse error" do
      lg_error('!lg * [[ * -log ]]').should eql("Subquery [[ * -log ]] has an action flag")
    end
  end

  context "given a top-level query with a query mode" do
    it "should throw a parse error" do
      lg_error('!lg !lg *').should eql("Query mode `!lg` not permitted at top-level")
    end
  end

  context "given a subquery with a query mode" do
    it "should parse the subquery just fine" do
      lg('!lg [[ !lm * ]]').subqueries.size.should eql(1)
    end
  end

  context "given a result index" do
    it "should report the correct result index" do
      lg('!lg * 22').result_index.should eql(22)
      lg('!lg * -5').result_index.should eql(-5)
      lg('!lg * [[ * -5 ]]').result_index.should eql(nil)
    end
  end

  context "given too many result indices" do
    it "should throw a parse error" do
      lg_error('!lg * 22 -5').should eql('Too many result indexes in query (extras: -5)')
    end
  end

  context "given a summary query" do
    it "should notice that it is a summary query" do
      lg('!lg * s=killer').summary_query?.should be_true
      lg('!lg * [[ * s=killer ]]').summary_query?.should be_false
    end

    it "should correctly identify the grouped fields" do
      lg('!lg *').summary_grouped_fields.should be_nil
      lg('!lg * s=killer').summary_grouped_fields.should eql(['killer'])
      lg('!lg * s=-killer,lg:place').summary_grouped_fields.should eql(['-killer', 'lg:place'])
    end
  end

  context "given a ratio query" do
    it "should notice that it is a ratio query" do
      lg('!lg * s=killer').ratio_query?.should be_false
      lg('!lg * s=char / win').ratio_query?.should be_true
    end

    it "should correctly find the ratio tail" do
      lg('!lg * / win').ratio_tail.text.should eql('win')
    end
  end
end
