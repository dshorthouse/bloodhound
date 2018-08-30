class Occurrence < ActiveRecord::Base
  has_many :occurrence_determiners
  has_many :determiners, through: :occurrence_determiners, source: :agent

  has_many :occurrence_recorders
  has_many :recorders, through: :occurrence_recorders, source: :agent

  has_many :user_occurrences
  has_many :users, through: :user_occurrences, source: :user

  has_one :taxon_occurrence
  has_one :taxon, through: :taxon_occurrence, source: :taxon

  def self.populate_agents
    @redis = Redis.new(db: 1)
    @redis.flushdb

    @recorders = File.open("/tmp/recorders", "a")
    @determiners = File.open("/tmp/determiners", "a")

    index = 0

    Occurrence.find_each(batch_size: 100_000) do |o|
      puts index if index % 100_000 == 0

      if o.recordedBy == o.identifiedBy
        save_agents(parse_agents(o.recordedBy), o.id, ["recorder", "determiner"])
      else
        save_agents(parse_agents(o.recordedBy), o.id, ["recorder"])
        save_agents(parse_agents(o.identifiedBy), o.id, ["determiner"])
      end
      index += 1
    end

    Agent.update_all("canonical_id = id")

    [@recorders, @determiners].each do |file|
      chunked_dir = "/tmp/#{File.basename(file)}_split/"
      FileUtils.mkdir(chunked_dir)
      system("split -l 100000 #{file} #{chunked_dir}")
      tmp_files = Dir.entries(chunked_dir).map{|f| File.join(chunked_dir, f) if !File.directory?(f)}.compact
      Parallel.map(tmp_files.each, progress: "Importing CSV", processes: 6) do |split_file|
        sql = "LOAD DATA INFILE '#{split_file}' 
               INTO TABLE occurrence_#{File.basename(file)} 
               FIELDS TERMINATED BY ',' 
               LINES TERMINATED BY '\n' 
               (occurrence_id, agent_id)"
        Occurrence.connection.execute sql
      end
      FileUtils.rm_rf(chunked_dir)
      file.close
      File.unlink(file)
    end

    @redis.flushdb
  end

  def self.parse_agents(namestring)
    names = []
    Bloodhound::AgentUtility.parse(namestring).each do |r|
      name = Bloodhound::AgentUtility.clean(r)
      if !name[:family].nil? && name[:family].length >= 3
        names << name
      end
    end
    names.uniq
  end

  def self.save_agents(names, id, roles)
    names.each do |name|
      family = name[:family].to_s
      given = name[:given].to_s
      fullname = [given, family].join(" ").strip
      agent_id = @redis.get(fullname)

      if !agent_id
        agent = Agent.create(family: family, given: given)
        agent_id = agent.id
        @redis.set(agent.fullname, agent_id)
      end

      roles.each do |role|
        if role == "recorder"
          @recorders.write([id,agent_id].join(",")+"\n")
        end
        if role == "determiner"
          @determiners.write([id,agent_id].join(",")+"\n")
        end
      end
    end
  end

  def self.populate_taxa
    @redis = Redis.new(db: 2)
    @redis.flushdb

    @taxon_occurrences = File.open("/tmp/taxon_occurrences", "w")
    @taxon_determiners = File.open("/tmp/taxon_determiners", "w")

    index = 0

    Occurrence.find_each(batch_size: 100_000) do |o|
      puts index if index % 100_000 == 0
      next if o.family.nil? || o.family == ''
      taxon_id = @redis.get(o.family)

      if taxon_id.nil?
        taxon = Taxon.create(family: o.family)
        taxon_id = taxon.id
        @redis.set(o.family, taxon_id)
      end

      @taxon_occurrences.write([o.id,taxon_id].join(",")+"\n")
      OccurrenceDeterminer.where(occurrence_id: o.id).pluck(:agent_id).each do |od|
        @taxon_determiners.write([od,taxon_id].join(",")+"\n")
      end
      index += 1
    end

    sql = "LOAD DATA INFILE '#{@taxon_occurrences.path}' 
           INTO TABLE #{File.basename(@taxon_occurrences)}
           FIELDS TERMINATED BY ',' 
           LINES TERMINATED BY '\n' 
           (occurrence_id, taxon_id)"
    Occurrence.connection.execute sql

    sql = "LOAD DATA INFILE '#{@taxon_determiners.path}' 
           INTO TABLE #{File.basename(@taxon_determiners)}
           FIELDS TERMINATED BY ',' 
           LINES TERMINATED BY '\n' 
           (agent_id, taxon_id)"
    Occurrence.connection.execute sql

    [@taxon_occurrences,@taxon_determiners].each do |file|
      file.close
      File.unlink(file)
    end

    @redis.flushdb
  end

  def coordinates
    lat = decimalLatitude.to_f
    long = decimalLongitude.to_f
    return nil if lat == 0 || long == 0 || lat > 90 || lat < -90 || long > 180 || long < -180
    [long, lat]
  end

  def agents
    {
      determiners: determiners.map{|d| { id: d[:id], given: d[:given], family: d[:family] } },
      recorders: recorders.map{|d| { id: d[:id], given: d[:given], family: d[:family] } }
    }
  end

end