require 'spec_helper'
require 'sql_connection'

describe 'postgres_binds' do
  it 'will convert ? placeholders to $n postgres placeholders' do
    expect(postgres_binds('select count(*) from logrecord where pname_id in (select id from l_pname where pname in (?, ?))')).to(
      eql('select count(*) from logrecord where pname_id in (select id from l_pname where pname in ($1, $2))'))
  end
end
