require 'test_unit_improvements'

class FileMonitorTest < Test::Unit::TestCase
  def setup
    # Put some test files in the directory test_data
    @relative_dir = 'test_data'
    @dir = File.expand_path(@relative_dir)
    @file1 = File.join(@dir, 'file1')
    @dir1 = File.join(@dir, 'dir1')
    @file2 = File.join(@dir1, 'file1')

    @relative_random_dir = 'test_data_2'
    @random_dir = File.expand_path(@relative_random_dir)
    FileUtils.rm_rf @random_dir
    FileUtils.mkdir_p @random_dir

    FileUtils.rm_rf @dir
    FileUtils.mkdir_p @dir1
    FileUtils.touch @file1
    FileUtils.touch @file2
    
    # Changes the access and modification time to be one minute in the past
    @past = Time.now - 60
    File.utime(@past, @past, @dir)
    File.utime(@past, @past, @dir1)
    File.utime(@past, @past, @file1)
    File.utime(@past, @past, @file2)
    
    # Clears the contents of the database
    Earth::File.delete_all
    Earth::Directory.delete_all
    Earth::Server.delete_all

    server = Earth::Server.this_server
    @directory = server.directories.create(:name => @dir, :path => @dir)

    @match_all_filter = Earth::Filter.create(:filename => '*', :uid => nil)    
  end
  
  def teardown
    # Tidy up
    File.chmod(0777, @dir1) if File.exist?(@dir1)
    FileUtils.rm_rf 'test_data'
    FileUtils.rm_rf 'test_data_2'
  end
  
  # Compare directory object with a directory on the filesystem
  def assert_directory(path, directory)
    assert_equal(path, directory.path)
    assert_equal(File.lstat(path), directory.stat)  
  end
  
  # Compare file object with a file on the filesystem
  def assert_file(path, file)
    assert_equal(File.dirname(path), file.directory.path)
    assert_equal(File.basename(path), file.name)
    assert_equal(File.lstat(path), file.stat)
  end

  def assert_directories(paths, directories)
    assert_equal(paths.size, directories.size)
    paths.each_index{|i| assert_directory(paths[i], directories[i])}
  end
  
  def assert_files(paths, files)
    assert_equal(paths.size, files.size)
    paths.each_index{|i| assert_file(paths[i], files[i])}
  end

  def assert_cached_sizes_match(directory)
    @directory.create_caches
    @directory.update_caches
    cached_size = @directory.find_cached_size_by_filter(@match_all_filter)
    cached_size.reload
    assert_equal(cached_size.size, @directory.size)
    assert_equal(cached_size.blocks, @directory.blocks)

    # Note: the following assertion assumes that no sparse or
    # compressed files have been created, as in that case disk usage
    # might be less than actual file size.
    #
    # Create files using /dev/random or something similar so that files are unlikely
    # to be compressed.
    # If testing on a filesystem with compression support and with unlucky random data
    # this might fail!!
    #assert(@directory.size <= @directory.blocks * 512)
  end
  
  # Check that files starting with "." are not ignored
  def test_dot_files
    FileUtils.touch 'test_data/.an_invisible_file'
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    assert_equal(".an_invisible_file", Earth::File.find_by_name('.an_invisible_file').name)
  end
  
  def test_added
    FileMonitor.update([@directory])
    assert_directories([@dir, @dir1], Earth::Directory.find(:all, :order => :id))
    assert_files([@file2, @file1], Earth::File.find(:all, :order => :id))
  end

  def test_removed
    FileMonitor.update([@directory])
    FileUtils.rm_rf 'test_data/dir1'
    FileUtils.rm 'test_data/file1'
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    assert_directories([@dir], Earth::Directory.find(:all, :order => :id))
    assert_files([], Earth::File.find(:all, :order => :id))
  end

  def test_removed2
    dir2 = File.join(@dir1, 'dir2')
    
    FileUtils.mkdir dir2
    FileUtils.touch File.join(dir2, 'file')
    sleep 1.01
    FileMonitor.update([@directory])
    FileUtils.rm_rf @dir1
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    assert_directories([@dir], Earth::Directory.find(:all, :order => :id))
    assert_files([@file1], Earth::File.find(:all, :order => :id))
  end

  def test_remove_multiple_files
    file1a = File.join(@dir, 'file1a')
    file1b = File.join(@dir, 'file1b')
    FileUtils.touch file1a
    FileUtils.touch file1b
    FileMonitor.update([@directory])
    sleep 1.5
    File.delete(file1a)
    File.delete(file1b)
    sleep 1.01
    FileMonitor.update([@directory])

    assert_directories([@dir, @dir1], Earth::Directory.find(:all, :order => :id))
    assert_files([@file2, @file1], Earth::File.find(:all, :order => :id))
  end

  def test_remove_multiple_directories
    dir2a = File.join(@dir, 'dir2a')    
    FileUtils.mkdir dir2a
    FileUtils.touch File.join(dir2a, 'file')

    dir2b = File.join(@dir, 'dir2b')    
    FileUtils.mkdir dir2b
    FileUtils.touch File.join(dir2b, 'file')

    sleep 1.01
    FileMonitor.update([@directory])
    sleep 1.5
    FileUtils.rm_rf dir2a
    FileUtils.rm_rf dir2b
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    assert_directories([@dir, @dir1], Earth::Directory.find(:all, :order => :id))
    assert_files([@file2, @file1], Earth::File.find(:all, :order => :id))
  end

  def test_remove_nested_directories_performance
    dir_a = File.join(@dir, 'dir_a')    
    FileUtils.mkdir dir_a
    dir_a_b = File.join(dir_a, 'dir_a_b')
    FileUtils.mkdir dir_a_b
    dir_a_b_c = File.join(dir_a_b, 'dir_a_b_c')
    FileUtils.mkdir dir_a_b_c

    sleep 1.01
    FileMonitor.update([@directory])

    assert_directories([@dir, @dir1, dir_a, dir_a_b, dir_a_b_c], Earth::Directory.find(:all, :order => :id))

    FileUtils.rm_rf dir_a

    sleep 1.01

    assert_deletes(1) { FileMonitor.update([@directory]) }
  end
  
  def test_changed
    FileMonitor.update([@directory])
    FileUtils.touch @file2
    # For the previous change to be noticed we need to create a new file as well
    # This is only strictly true for the PosixFileMonitor
    file3 = File.join(@dir1, 'file2')
    FileUtils.touch file3
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    assert_directories([@dir, @dir1], Earth::Directory.find(:all, :order => :id))
    assert_files([@file2, @file1, file3], Earth::File.find(:all, :order => :id))
  end
  
  def test_added_in_subdirectory
    FileMonitor.update([@directory])
    file3 = File.join(@dir1, 'file2')
    FileUtils.touch file3
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    assert_directories([@dir, @dir1], Earth::Directory.find(:all, :order => :id))
    assert_files([@file2, @file1, file3], Earth::File.find(:all, :order => :id))
  end

  # If the daemon doesn't have permission to list the directory
  # it should ignore it
  def test_permissions_directory
    # Remove all permission from directory
    mode = File.stat(@dir1).mode
    File.chmod(0000, @dir1)
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    assert_directories([@dir, @dir1], Earth::Directory.find(:all, :order => :id))
    assert_files([@file1], Earth::File.find(:all, :order => :id))

    # Add permissions back
    File.chmod(mode, @dir1)
  end
  
  def test_directory_executable_permissions
    # Make a directory readable but not executable
    mode = File.stat(@dir1).mode
    File.chmod(0444, @dir1)
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    assert_directories([@dir, @dir1], Earth::Directory.find(:all, :order => :id))
    assert_files([@file1], Earth::File.find(:all, :order => :id))

    # Add permissions back
    File.chmod(mode, @dir1)
  end
  
  def test_removed_watched_directory
    FileMonitor.update([@directory])
    FileUtils.rm_rf @dir
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    
    directories = Earth::Directory.find(:all, :order => :id)
    assert_equal(1, directories.size)
    assert_equal(@dir, directories[0].path)
    # Not checking the stat of the top directory as it has been deleted
    
    files = Earth::File.find(:all, :order => :id)
    assert_equal(0, files.size)
  end
  
  def test_directory_added
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)

    subdir = File.join(@dir, "subdir")
    FileUtils.mkdir subdir
    sleep 1.01
    FileMonitor.update([@directory])
    assert_directory(subdir, Earth::Directory.find_by_name("subdir"))
    assert(@directory == Earth::Directory.find_by_name("subdir").parent)
  end

  def create_random_file(file, size)
    assert_equal "", `dd 2>/dev/null >/dev/null if=/dev/random of=#{file} bs=1 count=#{size}`
  end

  def test_directory_cached_sizes_match
    # This performs various changes on a subdirectory and makes sure that
    # cached sizes are updated properly
    sleep 1.01
    FileMonitor.update([@directory])
    assert_cached_sizes_match(@directory)
    assert(@directory.find_cached_size_by_filter(@match_all_filter).size == 0)

    # Create a subdirectory and check that it's been created
    subdir = File.join(@dir, "subdir")
    FileUtils.mkdir subdir
    File.utime(@past, @past, subdir)

    sleep 1.01
    FileMonitor.update([@directory])
    assert_directory(subdir, Earth::Directory.find_by_name("subdir"))
    assert_equal(@directory, Earth::Directory.find_by_name("subdir").parent)
    assert_equal(Earth::Directory.find_by_name(@dir), Earth::Directory.find_by_name("subdir").parent)
    assert_equal(Earth::Directory.find_by_name(@dir).server, Earth::Directory.find_by_name("subdir").server)
    assert_cached_sizes_match(@directory)
    assert(@directory.find_cached_size_by_filter(@match_all_filter).size == 0)

    # Create a single file in the subdirectory and check that sizes still match
    prev_cached_size = @directory.find_cached_size_by_filter(@match_all_filter).size
    file1_size = 3254
    file1 = File.join(subdir, "sub-file1")
    create_random_file(file1, file1_size)
    sleep 1.01
    FileMonitor.update([@directory])
    assert_file(file1, Earth::File.find_by_name('sub-file1'))
    assert_equal(Earth::Directory.find_by_name("subdir"), Earth::File.find_by_name('sub-file1').directory)
    assert_equal(file1_size, Earth::File.find_by_name('sub-file1').size)
    assert_cached_sizes_match(@directory)
    assert_equal(file1_size, Earth::Directory.find_by_name("subdir").size)
    assert_equal(file1_size, Earth::Directory.find_by_name("subdir").find_cached_size_by_filter(@match_all_filter).size)
    assert_equal(file1_size, Earth::Directory.find_by_name(@dir).size)
    assert_equal(file1_size, Earth::Directory.find_by_name(@dir).find_cached_size_by_filter(@match_all_filter).size)
    assert_equal(@directory, Earth::Directory.find_by_name(@dir))
    assert_equal(file1_size, @directory.size)
    assert_equal(file1_size, @directory.find_cached_size_by_filter(@match_all_filter).size)
    assert_equal(@directory.find_cached_size_by_filter(@match_all_filter).size, file1_size)

    sleep 1 # FIXME

    # Create two files in the subdirectory and check that sizes still match
    prev_cached_size = @directory.find_cached_size_by_filter(@match_all_filter).size
    file2 = File.join(subdir, "sub-file2")
    file2_size = 1314
    create_random_file(file2, file2_size)
    file3 = File.join(subdir, "sub-file3")
    file3_size = 2131
    create_random_file(file3, file3_size)
    sleep 1.01
    FileMonitor.update([@directory])
    new_cached_size = @directory.find_cached_size_by_filter(@match_all_filter).size
    assert_equal(file2_size + file3_size, new_cached_size - prev_cached_size)
    assert_cached_sizes_match(@directory)

    # Delete one of the files and check that sizes still match
    #prev_cached_size = @directory.size
    #FileUtils.rm file1
    #FileMonitor.update(@directory)
    #assert_cached_sizes_match(@directory)

  end

  require 'find'
  def make_random_name
    name_length = 2 + rand(10)
    chars = ("a".."z").to_a
    new_name = ""
    1.upto(name_length) { |i| new_name << chars[rand(chars.size)] }
    new_name
  end

  def get_directories
    existing_paths = []
    Find.find(@random_dir) do |path|
      existing_paths << path
    end
    existing_paths
  end

  def test_extensive
    srand(12345)
    server = Earth::Server.find_or_create_by_name("random")
    random_directory = server.directories.create(:name => @random_dir, :path => @random_dir, :level => 0)
    random_directory.ensure_consistency
    FileMonitor.update([random_directory])
    random_directory.save
    random_directory.reload
    random_directory.ensure_consistency

    1.upto(30) do
      create_delete_random_dirs
      FileMonitor.update([random_directory])
      random_directory.reload
      random_directory.ensure_consistency
    end
  end

  def create_delete_random_dirs
    existing_paths = get_directories    
    delete_directory_trees_count = (rand(4) - 1).abs
    1.upto(delete_directory_trees_count) do
      existing_paths = get_directories
      if existing_paths.size > 1
        delete_index = 1 + rand(existing_paths.size - 1)   
        delete_candidate = existing_paths[delete_index]
        FileUtils.rm_rf delete_candidate
        RAILS_DEFAULT_LOGGER.debug "delete directory #{delete_candidate}"
      end
    end

    existing_paths = get_directories
    new_directory_trees_count = 0 + rand(5)
    (1..new_directory_trees_count).each do
      name = make_random_name()
      parent = existing_paths[rand(existing_paths.size)]
      dir = parent + "/" + name
      FileUtils.mkdir_p dir
      RAILS_DEFAULT_LOGGER.debug "create directory #{dir}"
      new_directory_subdirs_count = 0 + rand(2)
      (1..new_directory_subdirs_count).each do
        name = make_random_name()
        subdir = dir + "/" + name
        FileUtils.mkdir_p subdir
        RAILS_DEFAULT_LOGGER.debug "create directory #{subdir}"
      end
    end

    if false
      existing_paths = get_directories
      $stdout.print("\033[2J")
      $stdout.flush
      existing_paths.each do |path|
        puts path
      end
    end
  end

end
