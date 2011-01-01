
require 'set'

module Redcar
  class Project

    class FindFileDialog < FilterListDialog

      def self.storage
        @storage ||= begin
          storage = Plugin::Storage.new('find_file_dialog')
          storage.set_default('ignore_file_patterns', false)
          storage.set_default('ignore_files_that_match_these_regexes', [])
          storage.set_default('ignore_files_that_match_these_regexes_example_for_reference', [/.*\.class/i])
          storage
        end
      end

      attr_reader :project

      def initialize(project)
        super()
        @project = project
      end

      def close
        super
      end

      def paths_for(filter)
        paths = recent_files if filter.length < 2
        paths ||= find_files_from_list(filter, recent_files) + find_files(filter, project.path)
        paths.uniq
      end

      # search out and expand duplicates in shortened paths to their full length
      def expand_duplicates(display_paths, full_paths)
        duplicates = duplicates(display_paths)
        display_paths.each_with_index do |dp, i|
          if duplicates.include? dp
            display_paths[i] = display_path(full_paths[i], project.path.split('/')[0..-2].join('/'))
          end
        end
      end

      def update_list(filter)
        paths = paths_for filter
        @last_list = paths
        full_paths = paths
        display_paths = full_paths.map { |path| display_path(path) }
        if display_paths.uniq.length < full_paths.length
          display_paths = expand_duplicates(display_paths, full_paths)
        end
        display_paths
      end

      def selected(text, ix, closing=false)
        if @last_list
          close
          FileOpenCommand.new(@last_list[ix]).run
        end
      end

      private

      def recent_files
        files = project.recent_files
        ((files[0..-2]||[]).reverse + [files[-1]]).compact
      end

      # Find duplicates by checking if index from left and right equal
      def duplicates(enum)
        Set[*enum.select {|k| enum.index(k) != enum.rindex(k) }]
      end

      def display_path(path, first_remove_this_prefix = nil)
        n = -3
        if first_remove_this_prefix and path.index(first_remove_this_prefix) == 0
          path = path[first_remove_this_prefix.length..-1]
          # show the full subdirs in the case of collisions
          n = -100
        end

        if path.count('/') > 0
          count_back = [-path.count('/'), n].max
          path.split("/").last +
            " (" +
            path.split("/")[count_back..-2].join("/") +
            ")"
        else
          path
        end
      end

      def ignore_regexes
        self.class.storage['ignore_files_that_match_these_regexes']
      end

      def ignore_file?(filename)
        if self.class.storage['ignore_file_patterns']
          ignore_regexes.any? {|re| re =~ filename }
        end
      end

      def find_files_from_list(text, file_list)
        re = make_regex(text.gsub(/\s/, ""))
        file_list.select { |fn|
          fn.split('/').last =~ re and not ignore_file?(fn)
        }.compact
      end

      # Filters through the project files
      #
      # @todo
      # Take directories into account, instead of just
      # searching through the whole project.
      #
      def find_files(text, directories)
        files = project.all_files.sort.select {|fn| not ignore_file?(fn)}

        # Files are returned as absolute paths
        project_path = project.home_dir + "/"
        # by removing the home dir prefix for filtering
        files.map! { |file| file.sub(project_path, "") }
        res = match_files(text.gsub(/\s/, ""), files).sort { |a, b| a.length <=> b.length }
        # and putting it back on filtered results
        res.map { |file| project_path + file }
      end

      # Matches all files with the search string
      #
      # @param [String] query
      #  Search string, can contain full file name with path or just the file name.
      #  Name of each directory in the path doesn't have to be specified exactly.
      #
      # @param [String] files Array of files to match the search string
      #
      # @return [Array<String>]
      # array of all the files that match the path
      #
      # @todo Optimize the match algorithm
      #
      def self.match_files(query, files)
        res = files.map { |file_name| [file_name, match_file(query, file_name)] }
        # res = files.map { |file_name| [file_name, match_string(text, file_name.gsub("/", ""))] }
        res = res.select { |r| r[1] }.sort { |a, b| b[1] <=> a[1] }
        res.map { |r| r[0] }
      end


      # Test if search string matches file name
      #
      # @param [String] query
      #  Search string, can contain full file name with path or
      #  just the file name. Name of each directory in the path doesn't
      #  have to be specified exactly.
      #
      # @param [String] file_name
      #  File name of the target file, can contain either just the file name,
      #  or the whole path.
      #
      # @return [Integer]
      #  match score if match was successful, nil otherwise
      #
      # @todo Optimize the match algorithm
      #
      def self.match_file(query, file_name)
        pattern_path = query.split("/")
        file_path = file_name.split("/")

        pattern = pattern_path.pop
        file = file_path.pop

        score = 0

        # if there is path specified in the search
        if pattern_path && pattern_path.size > 0
          # doesn't match if search is deeper than the file,
          # eg. search: a/b and file is only b
          # or doesn't match the filename
          return false if file_path.size == 0 || !match_string(pattern, file)
          pattern = pattern_path.shift
          file = file_path.shift

          while true
            matched = false

            res = match_string(pattern, file)
            if res
              pattern = pattern_path.shift
              matched = true
              score += res
            end
            file = file_path.shift

            return false if file_path.empty? && !matched
            return score if pattern_path.empty? && matched
          end
        else
          match_string(pattern, file)
        end
      end


      # Fuzzy match on two strings
      #
      # @param [String] query search string
      # @param [String] string target to be searched
      #
      # @return [Integer] match score if match was successful, nil otherwise
      #
      # @todo Benchmark to see if regex is the fastest solution
      #
      def self.match_string(query, string)
        re = make_regex(query)
        score = 0
        last = nil

        m = string.match(re)
        return nil unless m

        m.captures.each_with_index do |capture, index|
          if index > 0
            # FIX - probably doesn't work properly on string with duplicate letters,
            # still better than nothing though. The string needs to be sliced after each
            # iteration in order to prevent this
            current_index = string.index(capture)
            last_index = string.index(last)
            score += 1 if current_index == last_index + 1
          end
          last = capture
        end
        score
      end
    end
  end
end
