require 'spec_helper'
require 'query/listgame_parser'
require 'sql/crawl_query'

describe '!lg behavior' do
  def self.query(query_str, &block)
    context(query_str) do
      let(:q) {
        Query::ListgameParser.parse('nick', query_str)
      }
      instance_eval(&block)
    end
  end

  query '!lg * vlong>0.17-a0-1357-g326445f' do
    it 'will search for vlongnum>?' do
      expect(q.to_s).to include('vlongnum>')
    end
  end

  query '!lg * god=tso' do
    it "will search for god='The Shining One'" do
      expect(q.to_s).to include("god='The Shining One'")
    end
  end

  query '!lm * god.abandon=tso' do
    it "will search for god.abandon='The Shining One'" do
      expect(q.to_s).to include("noun='The Shining One'")
    end
  end

  query "!lg * vmsg='succumbed to something\\'s poison gas' s=place" do
    it "will parse and print as expected" do
      expect(q.to_s).to eql("!lg * vmsg='succumbed to something\\'s poison gas' s=place o:n")
    end
  end

  query '!lg * $lm[uniq=Boris s=gid min=count(*) -1]:q gid=q:gid x=q:count' do
    it 'will order subquery by count(*) asc' do
      sql = q.join_tables[0].to_sql
      expect(sql).to include("ORDER BY COUNT(*) ASC")
    end
  end

  query '!lg from:$[@elliptic x=rownum():partition(char,o=-end):n] win n=1' do
    it 'will use lg as alias of from subquery' do
      expect(q.from_subquery).to eq(q.context)
      subquery = q.context
      expect(subquery.alias).to eql('lg')
    end
  end

  query '!lg from:$[@elliptic x=rownum():partition(char,o=-end):n] win n=1' do
    it 'will resolve id on the inner query' do
      inner = q.from_subquery
      col = inner.resolve_column(inner.bind(Sql::Field.field('id')), :internal)
      expect(col).not_to be_nil
      expect(col.table).to be_instance_of(Sql::QueryTable)
      expect(inner.query_tables.lookup!(col.table)).to eq(col.table)
    end

    it 'will resolve id on the inner query after duplicating' do
      z = q.dup
      inner = z.from_subquery
      col = inner.resolve_column(inner.bind(Sql::Field.field('id')), :internal)
      expect(col).not_to be_nil
      expect(col.table).to be_instance_of(Sql::QueryTable)
      expect(inner.query_tables.lookup!(col.table)).to eq(col.table)
    end
  end

  query '!lg * place="lg:br"' do
    it 'will search for place matching the text "lg:br"' do
      expect(q.to_sql).to include('place = ?')
    end
  end

  query '!lg * place=lg:br' do
    it 'will search for place = branch' do
      expect(q.to_sql).to include('place = l_br.br')
    end
  end

  query '!lg * map=${killermap}' do
    it 'will search for map_id = killermap_id (avoid join because of equality compare)' do
      expect(q.to_sql).to include('logrecord.mapname_id = logrecord.killermap_id')
    end
  end

  query '!lg * map<${killermap}' do
    it 'will search for l_map.mapname < l_map_1.mapname (join because of inequality compare)' do
      expect(q.to_sql).to include('l_map.mapname < l_map_1.mapname')
    end
  end

  query '!lg * killer=${ckiller}' do
    it 'will search for l_killer.killer = l_killer1.killer' do
      expect(q.to_sql).to include('CAST(l_killer.killer AS CITEXT) = CAST(l_killer_1.killer AS CITEXT)')
    end
  end

  query '!lg * ak gid!*$lm[ak abyss.exit x=gid]' do
    it 'will search for game_key_id NOT IN (SELECT game_key_id)' do
      expect(q.to_sql).to include('game_key_id NOT IN (SELECT milestone.game_key_id FROM milestone')
    end
  end

  describe "with an implied x=foo in a subquery" do
    # x=gid is implied in the subquery because the outer query is looking for a
    # field match, and the inner query is not explicit about matching on a
    # different field.
    query '!lg * ak gid!*$lm[ak abyss.exit]' do
      it 'will search for game_key_id NOT IN (SELECT game_key_id)' do
        expect(q.to_sql).to include('game_key_id NOT IN (SELECT milestone.game_key_id FROM milestone')
      end
    end
  end
end
