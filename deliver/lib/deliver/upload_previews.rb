require 'spaceship/tunes/tunes'
require 'digest/md5'

require_relative 'app_preview'
require_relative 'module'
require_relative 'loader'
require_relative 'queue_worker'
require_relative 'app_preview_iterator'

module Deliver
  # Upload previews to App Store Connect
  class UploadPreviews
    DeletePreviewJob = Struct.new(:app_preview, :localization, :app_preview_set)
    UploadPreviewJob = Struct.new(:app_preview_set, :path)

    NUMBER_OF_THREADS = Helper.test? ? 1 : [ENV.fetch("DELIVER_NUMBER_OF_THREADS", 10).to_i, 10].min

    def upload(options, previews)
      return if options[:skip_previews]
      return if options[:edit_live]

      app = options[:app]

      platform = Spaceship::ConnectAPI::Platform.map(options[:platform])
      version = app.get_edit_app_store_version(platform: platform)
      UI.user_error!("Could not find a version to edit for app '#{app.name}' for '#{platform}'") unless version

      UI.important("Will begin uploading previews for '#{version.version_string}' on App Store Connect")

      UI.message("Starting with the upload of previews...")
      previews_per_language = previews.group_by(&:language)

      localizations = version.get_app_store_version_localizations

      if options[:overwrite_previews]
        delete_previews(localizations, previews_per_language)
      end

      # Finding languages to enable
      languages = previews_per_language.keys
      locales_to_enable = languages - localizations.map(&:locale)

      if locales_to_enable.count > 0
        lng_text = "language"
        lng_text += "s" if locales_to_enable.count != 1
        Helper.show_loading_indicator("Activating #{lng_text} #{locales_to_enable.join(', ')}...")

        locales_to_enable.each do |locale|
          version.create_app_store_version_localization(attributes: {
            locale: locale
          })
        end

        Helper.hide_loading_indicator

        # Refresh version localizations
        localizations = version.get_app_store_version_localizations
      end

      upload_previews(localizations, previews_per_language)

      Helper.show_loading_indicator("Sorting previews uploaded...")
      sort_previews(localizations)
      Helper.hide_loading_indicator

      UI.success("Successfully uploaded previews to App Store Connect")
    end

    def delete_previews(localizations, previews_per_language, tries: 5)
      tries -= 1

      worker = QueueWorker.new(NUMBER_OF_THREADS) do |job|
        start_time = Time.now
        target = "#{job.localization.locale} #{job.app_preview_set.display_type} #{job.app_preview.id}"
        begin
          UI.verbose("Deleting '#{target}'")
          job.app_preview.delete!
          UI.message("Deleted '#{target}' -  (#{Time.now - start_time} secs)")
        rescue => error
          UI.error("Failed to delete preview #{target} - (#{Time.now - start_time} secs)")
          UI.error(error.message)
        end
      end

      iterator = AppPreviewIterator.new(localizations)
      iterator.each_app_preview do |localization, app_preview_set, app_preview|
        # Only delete previews if trying to upload
        next unless previews_per_language.keys.include?(localization.locale)

        UI.verbose("Queued delete preview job for #{localization.locale} #{app_preview_set.display_type} #{app_preview.id}")
        worker.enqueue(DeletePreviewJob.new(app_preview, localization, app_preview_set))
      end

      worker.start

      # Verify all previews have been deleted
      # Sometimes API requests will fail but previews will still be deleted
      count = iterator.each_app_preview_set.map { |_, app_preview_set| app_preview_set }
                .reduce(0) { |sum, app_preview_set| sum + app_preview_set.app_previews.size }

      UI.important("Number of previews not deleted: #{count}")
      if count > 0
        if tries.zero?
          UI.user_error!("Failed verification of all previews deleted... #{count} preview(s) still exist")
        else
          UI.error("Failed to delete all previews... Tries remaining: #{tries}")
          delete_previews(localizations, previews_per_language, tries: tries)
        end
      else
        UI.message("Successfully deleted all previews")
      end
    end

    def upload_previews(localizations, previews_per_language, tries: 5)
      tries -= 1

      # Upload previews
      worker = QueueWorker.new(NUMBER_OF_THREADS) do |job|
        begin
          UI.verbose("Uploading '#{job.path}'...")
          start_time = Time.now
          job.app_preview_set.upload_preview(path: job.path, wait_for_processing: false)
          UI.message("Uploaded '#{job.path}'... (#{Time.now - start_time} secs)")
        rescue => error
          UI.error(error)
        end
      end

      number_of_previews = 0
      iterator = AppPreviewIterator.new(localizations)
      iterator.each_local_preview(previews_per_language) do |localization, app_preview_set, preview, index|
        if index >= 3
          UI.error("Too many previews found for device '#{preview.device_type}' in '#{preview.language}', skipping this one (#{preview.path})")
          next
        end

        checksum = UploadPreviews.calculate_checksum(preview.path)
        duplicate = (app_preview_set.app_previews || []).any? { |s| s.source_file_checksum == checksum }

        # Enqueue uploading job if it's not duplicated otherwise preview will be skipped
        if duplicate
          UI.message("Previous uploaded. Skipping '#{preview.path}'...")
        else
          worker.enqueue(UploadPreviewJob.new(app_preview_set, preview.path))
        end

        number_of_previews += 1
      end

      worker.start

      UI.verbose('Uploading jobs are completed')

      Helper.show_loading_indicator("Waiting for all the previews processed...")
      states = wait_for_complete(iterator)
      Helper.hide_loading_indicator
      retry_upload_previews_if_needed(iterator, states, number_of_previews, tries, localizations, previews_per_language)

      UI.message("Successfully uploaded all previews")
    end

    # Verify all previews have been processed
    def wait_for_complete(iterator)
      loop do
        states = iterator.each_app_preview.map { |_, _, app_preview| app_preview }.each_with_object({}) do |app_preview, hash|
          state = app_preview.asset_delivery_state['state']
          hash[state] ||= 0
          hash[state] += 1
        end

        is_processing = states.fetch('UPLOAD_COMPLETE', 0) > 0
        return states unless is_processing

        UI.verbose("There are still incomplete previews - #{states}")
        sleep(5)
      end
    end

    # Verify all previews states on App Store Connect are okay
    def retry_upload_previews_if_needed(iterator, states, number_of_previews, tries, localizations, previews_per_language)
      is_failure = states.fetch("FAILED", 0) > 0
      is_missing_preview = states.reduce(0) { |sum, (k, v)| sum + v } != number_of_previews && !previews_per_language.empty?

      if is_failure || is_missing_preview
        if tries.zero?
          incomplete_preview_count = states.reject { |k, v| k == 'COMPLETE' }.reduce(0) { |sum, (k, v)| sum + v }
          UI.user_error!("Failed verification of all previews uploaded... #{incomplete_preview_count} incomplete preview(s) still exist")
        else
          UI.error("Failed to upload all previews... Tries remaining: #{tries}")
          # Delete bad entries before retry
          iterator.each_app_preview do |_, _, app_preview|
            app_preview.delete! unless app_preview.complete?
          end
          upload_previews(localizations, previews_per_language, tries: tries)
        end
      end
    end

    def sort_previews(localizations)
      iterator = AppPreviewIterator.new(localizations)

      # Re-order previews within app_preview_set
      worker = QueueWorker.new(NUMBER_OF_THREADS) do |app_preview_set|
        original_ids = app_preview_set.app_previews.map(&:id)
        sorted_ids = app_preview_set.app_previews.sort_by(&:file_name).map(&:id)
        if original_ids != sorted_ids
          app_preview_set.reorder_previews(app_preview_ids: sorted_ids)
        end
      end

      iterator.each_app_preview_set do |_, app_preview_set|
        worker.enqueue(app_preview_set)
      end

      worker.start
    end

    def collect_previews(options)
      return [] if options[:skip_previews]
      return collect_previews_for_languages(options[:previews_path], options[:ignore_language_directory_validation])
    end

    def collect_previews_for_languages(path, ignore_validation)
      previews = []
      extensions = '{mov,m4v,mp4}'

      available_languages = UploadPreviews.available_languages.each_with_object({}) do |lang, lang_hash|
        lang_hash[lang.downcase] = lang
      end

      Loader.language_folders(path, ignore_validation).each do |lng_folder|
        language = File.basename(lng_folder)

        # # Check to see if we need to traverse multiple platforms or just a single platform
        # if language == Loader::APPLE_TV_DIR_NAME || language == Loader::IMESSAGE_DIR_NAME
        #   previews.concat(collect_previews_for_languages(File.join(path, language), ignore_validation))
        #   next
        # end

        files = Dir.glob(File.join(lng_folder, "*.#{extensions}"), File::FNM_CASEFOLD).sort
        next if files.count == 0

        framed_previews_found = Dir.glob(File.join(lng_folder, "*_framed.#{extensions}"), File::FNM_CASEFOLD).count > 0

        UI.important("Framed previews are detected! 🖼 Non-framed preview files may be skipped. 🏃") if framed_previews_found

        language_dir_name = File.basename(lng_folder)

        if available_languages[language_dir_name.downcase].nil?
          UI.user_error!("#{language_dir_name} is not an available language. Please verify that your language codes are available in iTunesConnect. See https://developer.apple.com/library/content/documentation/LanguagesUtilities/Conceptual/iTunesConnect_Guide/Chapters/AppStoreTerritories.html for more information.")
        end

        language = available_languages[language_dir_name.downcase]

        files.each do |file_path|
          previews << AppPreview.new(file_path, language)
        end
      end

      # Checking if the device type exists in spaceship
      # Ex: iPhone 6.1 inch isn't supported in App Store Connect but need
      # to have it in there for frameit support
      unaccepted_device_shown = false
      previews.select! do |preview|
        exists = !preview.device_type.nil?
        unless exists
          UI.important("Unaccepted device previews are detected! 🚫 Preview file will be skipped. 🏃") unless unaccepted_device_shown
          unaccepted_device_shown = true

          UI.important("🏃 Skipping preview file: #{preview.path} - Not an accepted App Store Connect device...")
        end
        exists
      end

      return previews
    end

    # helper method so Spaceship::Tunes.client.available_languages is easier to test
    def self.available_languages
      if Helper.test?
        FastlaneCore::Languages::ALL_LANGUAGES
      else
        Spaceship::Tunes.client.available_languages
      end
    end

    # helper method to mock this step in tests
    def self.calculate_checksum(path)
      bytes = File.binread(path)
      Digest::MD5.hexdigest(bytes)
    end
  end
end