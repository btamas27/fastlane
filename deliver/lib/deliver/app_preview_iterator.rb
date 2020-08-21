module Deliver
  # This is a convinient class that enumerates app store connect's previews in various degrees.
  class AppPreviewIterator
    NUMBER_OF_THREADS = Helper.test? ? 1 : [ENV.fetch("DELIVER_NUMBER_OF_THREADS", 10).to_i, 10].min

    # @param localizations [Array<Spaceship::ConnectAPI::AppStoreVersionLocalization>]
    def initialize(localizations)
      @localizations = localizations
    end

    # Iterate app_preview_set over localizations
    #
    # @yield [localization, app_preview_set]
    # @yieldparam [optional, Spaceship::ConnectAPI::AppStoreVersionLocalization] localization
    # @yieldparam [optional, Spaceship::ConnectAPI::AppStorePreviewSet] app_preview_set
    def each_app_preview_set(&block)
      return enum_for(__method__) unless block_given?

      # Collect app_screenshot_sets from localizations in parallel but
      # limit the number of threads working at a time with using `lazy` and `force` controls
      # to not attack App Store Connect
      results = @localizations.each_slice(NUMBER_OF_THREADS).lazy.map do |localizations|
        localizations.map do |localization|
          Thread.new do
            [localization, localization.get_app_preview_sets]
          end
        end
      end.flat_map do |threads|
        threads.map { |t| t.join.value }
      end.force

      results.each do |localization, app_preview_sets|
        app_preview_sets.each do |app_preview_set|
          yield(localization, app_preview_set)
        end
      end
    end

    # Iterate app_screenshot over localizations and app_screenshot_sets
    #
    # @yield [localization, app_screenshot_set, app_screenshot]
    # @yieldparam [optional, Spaceship::ConnectAPI::AppStoreVersionLocalization] localization
    # @yieldparam [optional, Spaceship::ConnectAPI::AppStorePreviewSet] app_preview_set
    # @yieldparam [optional, Spaceship::ConnectAPI::AppStorePreview] app_preview
    def each_app_preview(&block)
      return enum_for(__method__) unless block_given?

      each_app_preview_set do |localization, app_preview_set|
        app_preview_set.app_previews.each do |app_preview|
          yield(localization, app_preview_set, app_preview)
        end
      end
    end

    # Iterate given local app_preview over localizations and app_preview_sets with index within each app_preview_set
    #
    # @param previews_per_language [Hash<String, Array<Deliver::AppPreview>]
    # @yield [localization, app_preview_set, app_preview, index]
    # @yieldparam [optional, Spaceship::ConnectAPI::AppStoreVersionLocalization] localization
    # @yieldparam [optional, Spaceship::ConnectAPI::AppStorePreviewSet] app_preview_set
    # @yieldparam [optional, Deliver::AppPreview] preview
    # @yieldparam [optional, Integer] index a number represents which position the preview will be
    def each_local_preview(previews_per_language, &block)
      return enum_for(__method__, previews_per_language) unless block_given?

      # Iterate over all the previews per language and display_type
      # and then enqueue them to worker one by one if it's not duplicated on App Store Connect
      previews_per_language.map do |language, previews_for_language|
        localization = @localizations.find { |l| l.locale == language }
        [localization, previews_for_language]
      end.reject do |localization, _|
        localization.nil?
      end.each do |localization, previews_for_language|
        iterate_over_previews_per_language(localization, previews_for_language, &block)
      end
    end

    private

    def iterate_over_previews_per_language(localization, previews_for_language, &block)
      app_preview_sets_per_display_type = localization.get_app_preview_sets.map { |set| [set.preview_type, set] }.to_h
      previews_per_display_type = previews_for_language.reject { |preview| preview.device_type.nil? }.group_by(&:device_type)

      previews_per_display_type.each do |display_type, previews|
        # Create AppPreviewSet for given display_type if it doesn't exist
        app_preview_set = app_preview_sets_per_display_type[display_type]
        app_preview_set ||= localization.create_app_preview_set(attributes: { previewType: display_type })
        iterate_over_previews_per_display_type(localization, app_preview_set, previews, &block)
      end
    end

    def iterate_over_previews_per_display_type(localization, app_preview_set, previews, &block)
      previews.each.with_index do |preview, index|
        yield(localization, app_preview_set, preview, index)
      end
    end
  end
end
