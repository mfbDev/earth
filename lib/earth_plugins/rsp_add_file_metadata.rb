# This class TODO comments
#
# Author:: Mohammad Bamogaddam

class RspAddFileMetadata < EarthPlugin
  
  # constant variable used to save rsp naming convention
  RSP_KEYS = ["job","sequence","shot"]
  RSP_KEYS_TYPES = ["string","string","string"]
  
  # the +rsp_keys+ method returns array of rsp keys
  def self.rsp_keys
    RSP_KEYS
  end
  
  def self.plugin_name
    "EarthRspAddFileMetadata"
  end
  
  def self.migration_up
    plugin_object = Earth::PluginDescriptor.find_by_name(self.plugin_name)
    # add rsp_keys in the metadata_attributes table
    for i in 0..RSP_KEYS.size-1 do
      Earth::MetadataAttribute.create :name => RSP_KEYS[i], :metadata_type => RSP_KEYS_TYPES[i], :plugin_descriptor_id => plugin_object.id
    end
    
    # add metadata to all existed files
    files = Earth::File.find(:all)
    add_file_metadata = RspAddFileMetadata.new
    for file in files do
      metadata = add_file_metadata.file_metadata(file)
      EarthApi::MetadataApi.save_file_metadata(file, metadata)
    end
  end
  
  def self.migration_down
    plugin_object = Earth::PluginDescriptor.find_by_name(self.plugin_name)
    # remove all related metadata
    EarthApi::MetadataApi.remove_metadata_for_plugin(plugin_object)
  end
  
  def self.plugin_version
    3
  end
  
  def initialize
    # read the (file) parameter from the plugin session
    file = get_param(:file)
    unless file.nil?
      metadata = file_metadata(file)
      EarthApi::MetadataApi.save_file_metadata(file, metadata)
    end
  end
  
  # the +file_metadata+ method returns hash of keys and values
  # representing the passed file metadata
  # === Parameters
  # * _file_ = a file object, represent a record in files table
  #
  # === Example
  # r = RspMetadata.new
  # f1 = Earth::File.find(:first, :conditions => ["name = ?", "pic_003.jpg"])
  # r.file_metadata(f1) => {"job" => "", "sequence" => "", "shot" => ""}
  #
  def file_metadata(file)
    # Find the parent directory for the given file
    # TODO: catch any exception (record not found, etc)
    directory = Earth::Directory.find(file.directory_id)
    # save the path
    path = directory.path
    # parse the path, look for keys and save metadata
    metadata = parse_path(path)
    return metadata
  end
  
  private
  
  # the +parse_path+ parses a given path looking for keys
  # returns hash of keys and values
  # === Parameters
  # * _path_ = String represent some path (e.g. "rsp/job_001/sequence_003/shot_104")
  # === Example
  # parse_path("rsp/job_001/sequence_003/shot_104") => {"job" => "_001", "sequence" => "_003", "shot" => "_104"}
  #
  def parse_path(path)
    metadata = {}
    # split the path into tokens
    tokens = path.split('/')
    # loop all over the tokens looking for keys (or something similar to keys)
    tokens.each do |token|
      # find the index of the key (alike)
      index = match_one_of(RSP_KEYS, token)
      if index >= 0
        # extract the value
        value = extract_value(RSP_KEYS[index], token)
        # save key, value pairs
        metadata[RSP_KEYS[index]] = value
      end
    end
    metadata
  end
  
  # the +match_one_of+ method search in array of keys and comparing each key with a string (_test_)
  # if one of the keys is found in _test_ => return its index
  # if not => return -1
  # === Parameters
  # * _keys_ = Array of Strings
  # * _test_ = String
  # === Example:
  # keys = ["job","sequence","shot"]
  # test = "job_LOR"
  # match_one_of(keys, test) => 0 (index of "job")
  def match_one_of(keys, test)
    keys.each do |key|
      if test =~ Regexp.new(key)
        return keys.index(key)
      end
    end
    return -1
  end
  
  # the +extract_value+ method extracts a key value from a String (_test_)
  # returns a String represent the value of the _key_ in _test_
  # === Pararmeters
  # * _key_ = String (e.g. "job")
  # * _test = String (e.g. "job_LOR")
  # === Example
  # extract_value("job", "job_LOR") => "_LOR"
  def extract_value(key, test)
    test.sub(Regexp.new(key), "")
  end
  
end
