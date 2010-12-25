
module Redcar
  class ApplicationSWT
    class ModelessListDialogController

      DEFAULT_HEIGHT = 100
      DEFAULT_WIDTH  = 300

      def initialize(model)
        @model  = model
        parent  = ApplicationSWT.display
        @shell  = Swt::Widgets::Shell.new(parent, Swt::SWT::MODELESS)
        @list   = Swt::Widgets::List.new(@shell, Swt::SWT::V_SCROLL | Swt::SWT::SINGLE)
        layout  = Swt::Layout::GridLayout.new(1, true)
        layout.marginHeight    = 0
        layout.marginWidth     = 0
        layout.verticalSpacing = 0
        @shell.setLayout(layout)
        @list.set_layout_data(Swt::Layout::GridData.new(Swt::Layout::GridData::FILL_BOTH))
        @key_listener = KeyListener.new(@model)
        @list.add_key_listener(@key_listener)
        @shell.pack
        @shell.set_size DEFAULT_WIDTH, DEFAULT_HEIGHT
        attach_listeners
      end

      def set_size(width,height)
        @shell.set_size width, height
      end

      def set_location(offset)
        x, y = Swt::GraphicsUtils.below_pixel_location_at_offset(offset)
        @shell.set_location(x,y) if x and y
      end

      # The currently selected value
      def selection_value
        @list.get_selection.first
      end

      def selection_index
        @list.get_selection_index
      end

      # Close the dialog
      def close
        @list.remove_key_listener(@key_listener)
        @shell.dispose
      end

      # Open the dialog
      def open
        ApplicationSWT.register_shell(@shell)
        @shell.open
      end

      # Update the list items
      #
      # @param [Array<String>] items
      def update_list(items)
        @list.set_items items
      end

      def attach_listeners
        @model.add_listener(:open, &method(:open))
        @model.add_listener(:close, &method(:close))
        @model.add_listener(:set_location, &method(:set_location))
        @model.add_listener(:set_size, &method(:set_size))
      end

      class KeyListener

        def initialize(model)
          @model = model
        end

        def key_pressed(e)
          case e.keyCode
          when Swt::SWT::CR, Swt::SWT::LF
            @model.selected
          when Swt::SWT::ARROW_RIGHT
            items = @model.next_list
            @model.update_list(items) if items
          when Swt::SWT::ARROW_LEFT
            items = @model.previous_list
            @model.update_list(items) if items
          when Swt::SWT::ESC
            @model.close
          end
        end

        def key_released(e)
        end
      end
    end
  end
end