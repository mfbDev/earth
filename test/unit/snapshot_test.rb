class SnapshotTest < Test::Unit::TestCase
  def setup
    @dir = File.expand_path('test_data')
    @file2 = File.join(@dir, 'file1')
    @dir2 = File.join(@dir, 'dir2')

    FileUtils.rm_rf @dir
    FileUtils.mkdir @dir
    FileUtils.touch @file2
    FileUtils.mkdir @dir2
    
    # Clears the contents of the database
    Server.delete_all
    FileInfo.delete_all
    Directory.delete_all

    @queue = FileDatabaseUpdater.new
    directory = @queue.directory_added(nil, @dir)
    @monitor = Snapshot.new(directory, @queue)
  end

  def teardown
    FileUtils.rm_rf @dir
  end
  
  def test_simple
    @monitor.update

    directories = Directory.find_all
    assert_equal(2, directories.size)
    assert_equal(@dir, directories[0].path)
    assert_equal(File.lstat(@dir), directories[0].stat)
    assert_equal(@dir2, directories[1].path)
    assert_nil(directories[1].stat)

    files = FileInfo.find_all
    assert_equal(1, files.size)
    assert_equal(@dir, files[0].directory.path)
    assert_equal('file1', files[0].name)
  end
  
  def test_removed_watched_directory
    @monitor.update
    FileUtils.rm_rf @dir
    @monitor.update
    
    directories = Directory.find_all
    assert_equal(1, directories.size)
    assert_equal(@dir, directories[0].path)
    # Not checking the stat of the top directory as it has been deleted
    
    files = FileInfo.find_all
    assert_equal(0, files.size)
  end
end
