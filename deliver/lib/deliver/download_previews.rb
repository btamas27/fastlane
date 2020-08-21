require_relative 'module'
require 'spaceship'
require 'open-uri'
require 'ffmpeg'
require_relative 'queue_worker'

module Deliver
  class DownloadPreviews
    DownloadPreviewsJob = Struct.new(:app_preview, :localization, :app_preview_set)

    NUMBER_OF_THREADS = Helper.test? ? 1 : [ENV.fetch("DELIVER_NUMBER_OF_THREADS", 10).to_i, 10].min

    def self.run(options, path)
      UI.message("Downloading all existing previews...")
      download(options, path)
      UI.success("Successfully downloaded all existing previews")
    rescue => ex
      UI.error(ex)
      UI.error("Couldn't download already existing screenshots from App Store Connect.")
    end

    def self.download(options, folder_path)
      app = options[:app]

      platform = Spaceship::ConnectAPI::Platform.map(options[:platform])
      if options[:use_live_version]
        version = app.get_live_app_store_version(platform: platform)
        UI.user_error!("Could not find a live version on App Store Connect. Try using '--use_live_version false'") if version.nil?
      else
        version = app.get_edit_app_store_version(platform: platform)
        UI.user_error!("Could not find an edit version on App Store Connect. Try using '--use_live_version true'") if version.nil?
      end

      localizations = version.get_app_store_version_localizations.select { |localization| localization.locale.eql?('en-US') }
      Helper.show_loading_indicator("Downloading preview...")
      download_previews_2(localizations, folder_path)
      Helper.hide_loading_indicator
      # threads = []
      # localizations.each do |localization|
      #   threads << Thread.new do
      #     download_previews(folder_path, localization)
      #   end
      # end
      # threads.each(&:join)
    end

    def self.download_previews_2(localizations, folder_path)
      tries = -1

      worker = QueueWorker.new(NUMBER_OF_THREADS) do |job|
        start_time = Time.now
        target = "#{job.localization.locale} #{job.app_preview_set.display_type} #{job.app_preview.id}"
        begin
          # UI.verbose("Downloading '#{target}'")
          job.app_preview.download
            # UI.message("Downloaded '#{target}' -  (#{Time.now - start_time} secs)")
        rescue => error
          UI.error("Failed to download preview #{target} - (#{Time.now - start_time} secs)")
          UI.error(error.message)
        end
      end

      localizations.each do |localization|
        language = localization.locale
        preview_sets = localization.get_app_preview_sets
        preview_sets.each do |preview_set|
          preview_set.app_previews.each_with_index do |preview, index|
            file_name = [index, preview_set.preview_type, index].join("_")
            original_file_extension = File.extname(preview.file_name).strip.downcase[1..-1]
            file_name += "." + original_file_extension

            url = preview.video_url
            next if url.nil?

            # UI.message("Downloading existing preview '#{file_name}' for language '#{language}'")

            containing_folder = File.join(folder_path, language)
            begin
              FileUtils.mkdir_p(containing_folder)
            rescue
              # if it's already there
            end

            path = File.join(containing_folder, file_name)

            puts("ffmpeg -hide_banner -loglevel panic -i #{url} -c copy #{path}")

            # system("ffmpeg -hide_banner -loglevel panic -i #{url} -c copy #{path}")

            # # If the screen shot is for an appleTV we need to store it in a way that we'll know it's an appleTV
            # # screen shot later as the screen size is the same as an iPhone 6 Plus in landscape.
            # if preview_sets.apple_tv?
            #   containing_folder = File.join(folder_path, "appleTV", language)
            # else
            #   containing_folder = File.join(folder_path, language)
            # end
            #
            # if preview_sets.imessage?
            #   containing_folder = File.join(folder_path, "iMessage", language)
            # end
            #
            # puts(containing_folder)
          end
        end

        worker.start

      end
    end
  end
end
