//  Modified by Mark Story [mark@mark-story.com], 2020
//  Modified by Popye [sailor3101@gmail.com], 2017
//
//  Original copyright (C) 2014, Tom Beckmann
//  https://github.com/tom95/gala-alternate-alt-tab
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Clutter;
using Meta;

namespace Gala.Plugins.AltTabPlus
{
    public delegate void ObjectCallback(Object object);

    public const string SWITCHER_PLUGIN_VERSION = "0.2";

    // Visual Settings
    public const string ACTIVE_ICON_COLOR = "#5e5e6448";
    public const int ICON_SIZE = 96;
    public const string WRAPPER_BACKGROUND_COLOR = "#EAEAEAC8";
    public const int WRAPPER_BORDER_RADIUS = 12;
    public const int WRAPPER_PADDING = 12;
    // Set to the default font for elementary OS.
    // See: https://github.com/elementary/default-settings/blob/ff9a432dada00bfeadcb3c423e6cfbfd1c90f978/overrides/default-settings.gschema.override.in#L27
    // If a font is not set, defaults to Open Sans @ 9pt on elementary OS 5.1.7.
    public const string CAPTION_FONT_NAME = "Inter 9";
    public const string CAPTION_COLOR = "#2e2e31";

    public class Main : Gala.Plugin
    {
        const int MIN_OFFSET = 64;
        const int FIX_TIMEOUT_INTERVAL = 100;

        public bool opened { get; private set; default = false; }

        Gala.WindowManager? wm = null;
        Gala.ModalProxy modal_proxy = null;

        Actor container;
        RoundedActor wrapper;
        RoundedActor indicator;
        Text caption;

        int modifier_mask;

        WindowIcon? cur_icon = null;

        public override void initialize(Gala.WindowManager wm)
        {
            this.wm = wm;

            KeyBinding.set_custom_handler("switch-applications", (Meta.KeyHandlerFunc) handle_switch_windows);
            KeyBinding.set_custom_handler("switch-applications-backward", (Meta.KeyHandlerFunc) handle_switch_windows);
            KeyBinding.set_custom_handler("switch-windows", (Meta.KeyHandlerFunc) handle_switch_windows);
            KeyBinding.set_custom_handler("switch-windows-backward", (Meta.KeyHandlerFunc) handle_switch_windows);

            wrapper = new RoundedActor(Color.from_string(WRAPPER_BACKGROUND_COLOR), WRAPPER_BORDER_RADIUS);
            wrapper.reactive = true;
            wrapper.set_pivot_point(0.5f, 0.5f);
            wrapper.key_release_event.connect(key_release_event);
            wrapper.key_focus_out.connect(key_focus_out);

            var layout = new FlowLayout(FlowOrientation.HORIZONTAL);
            container = new Actor();
            container.layout_manager = layout;
            container.reactive = true;
            container.button_press_event.connect(container_mouse_press);
            container.motion_event.connect(container_motion_event);

            indicator = new RoundedActor(Color.from_string(ACTIVE_ICON_COLOR), WRAPPER_BORDER_RADIUS);

            indicator.margin_left = indicator.margin_top =
                indicator.margin_right = indicator.margin_bottom = 0;
            indicator.set_pivot_point(0.5f, 0.5f);

            caption = new Text.full(CAPTION_FONT_NAME, "", Color.from_string(CAPTION_COLOR));
            caption.set_pivot_point(0.5f, 0.5f);
            caption.set_ellipsize(Pango.EllipsizeMode.END);
            caption.set_line_alignment(Pango.Alignment.CENTER);

            wrapper.add_child(indicator);
            wrapper.add_child(container);
            wrapper.add_child(caption);
        }

        public override void destroy()
        {
            wrapper.destroy();
            container.destroy();
            indicator.destroy();
            caption.destroy();

            if (wm == null) {
                return;
            }
        }

        [CCode (instance_pos = -1)] void handle_switch_windows(
                    Display display, Screen screen, Window? window,
        #if HAS_MUTTER314
                    Clutter.KeyEvent event, KeyBinding binding)
        #else
                    X.Event event, KeyBinding binding)
        #endif
        {
            var workspace = screen.get_active_workspace();

            // copied from gnome-shell, finds the primary modifier in the mask
            var mask = binding.get_mask();
            if (mask == 0) {
                modifier_mask = 0;
            } else {
                modifier_mask = 1;
                while (mask > 1) {
                    mask >>= 1;
                    modifier_mask <<= 1;
                }
            }

            if (!opened) {
                var windowsExist = collect_windows(display, workspace);
                if (!windowsExist) {
                  return;
                }
                open_switcher();
                update_indicator_position(true);
            }

            var binding_name = binding.get_name();
            var backward = binding_name.has_suffix("-backward");

            next_window(display, workspace, backward);
        }

        bool collect_windows(Display display, Workspace? workspace)
        {
            var windows = display.get_tab_list(TabList.NORMAL, workspace);

            if (windows == null) {
                return false;
            }

            var current_window = display.get_tab_current(TabList.NORMAL, workspace);

            container.width = -1;
            container.destroy_all_children();

            // Update wnck
            Wnck.Screen.get_default().force_update();

            foreach (var window in windows) {
                var icon = new WindowIcon(window, ICON_SIZE);
                if (window == current_window) {
                    cur_icon = icon;
                }
                icon.set_pivot_point(0.5f, 0.5f);
                container.add_child(icon);

            }

            return true;
        }

        void open_switcher()
        {
            if (container.get_n_children() == 0) {
                return;
            }

            if (opened) {
                return;
            }

            var screen = wm.get_screen();
            indicator.set_easing_duration(200);

            container.margin_left = container.margin_top =
                container.margin_right = container.margin_bottom = (WRAPPER_PADDING * 3);

            var l = container.layout_manager as FlowLayout;
            l.column_spacing = l.row_spacing = WRAPPER_PADDING;

            indicator.visible = false;
            indicator.resize(
                ICON_SIZE + WRAPPER_PADDING * 2,
                ICON_SIZE + WRAPPER_PADDING * 2
            );
            caption.visible = false;
            caption.margin_bottom = caption.margin_top = WRAPPER_PADDING;

            var monitor = screen.get_primary_monitor();
            var geom = screen.get_monitor_geometry(monitor);

            float container_width;
            container.get_preferred_width(
                ICON_SIZE + container.margin_left + container.margin_right,
                null,
                out container_width
            );
            if (container_width + MIN_OFFSET * 2 > geom.width) {
                container.width = geom.width - MIN_OFFSET * 2;
            }

            float nat_width, nat_height;
            container.get_preferred_size(null, null, out nat_width, null);

            if (container.get_n_children() == 1) {
                nat_width -= WRAPPER_PADDING;
            }
            container.get_preferred_size(null, null, null, out nat_height);

            wrapper.opacity = 0;
            wrapper.resize(
                (int) nat_width,
                (int) (
                    (nat_height) +
                    (caption.height - (container.margin_bottom - caption.height)) / 2
                )
            );
            wrapper.set_position(
                geom.x + (geom.width - wrapper.width) / 2,
                geom.y + (geom.height - wrapper.height) / 2
            );


            wm.ui_group.insert_child_above(wrapper, null);

            wrapper.save_easing_state();
            wrapper.set_easing_duration(200);
            wrapper.opacity = 255;
            wrapper.restore_easing_state();

            modal_proxy = wm.push_modal();
            modal_proxy.keybinding_filter = keybinding_filter;
            opened = true;

            wrapper.grab_key_focus();

            // if we did not have the grab before the key was released, close immediately
            if ((get_current_modifiers() & modifier_mask) == 0) {
                close_switcher(get_timestamp());
            }
        }

        void close_switcher(uint32 time)
        {
            if (!opened) {
                return;
            }

            wm.pop_modal(modal_proxy);
            opened = false;

            var window = cur_icon.window;
            if (window == null) {
                return;
            }

            var workspace = window.get_workspace();
            if (workspace != wm.get_screen().get_active_workspace()) {
                workspace.activate_with_focus(window, time);
            } else {
                window.activate(time);
            }

            ObjectCallback remove_actor = () => {
                wm.ui_group.remove_child(wrapper);
            };

            wrapper.save_easing_state();
            wrapper.set_easing_duration(100);
            wrapper.opacity = 0;

            var transition = wrapper.get_transition("opacity");
            if (transition != null) {
                transition.completed.connect(() => remove_actor(this));
            } else {
                remove_actor(this);
            }
            wrapper.restore_easing_state();
        }

        void next_window(Display display, Workspace? workspace, bool backward)
        {
            Actor actor;
            var current = cur_icon;

            if (!backward) {
                actor = current.get_next_sibling();
                if (actor == null) {
                    actor = container.get_first_child();
                }
            } else {
                actor = current.get_previous_sibling();
                if (actor == null) {
                    actor = container.get_last_child();
                }
            }

            cur_icon = (WindowIcon) actor;
            update_indicator_position();
        }

        void update_caption_text(bool initial = false) {
            // FIXME: width contains incorrect value, if we have one children in container
            if (container.get_n_children () == 1 && container.width > ICON_SIZE + WRAPPER_PADDING) {
                GLib.Timeout.add(FIX_TIMEOUT_INTERVAL, () => {
                    update_caption_text(initial);
                    return false;
                }, GLib.Priority.DEFAULT);
                return;
            }

            var current_window = cur_icon.window;
            var current_caption = "n/a";
            if (current_window != null) {
                ulong xid = (ulong) current_window.get_xwindow();
                var wnck_current_window = Wnck.Window.get(xid);
                if (wnck_current_window != null) {
                    current_caption = wnck_current_window.get_name();
                }
            }
            caption.set_text(current_caption);

            if (initial) {
                caption.visible = true;
            }

            // Make caption smaller than the wrapper, so it doesn't overflow.
            caption.width = wrapper.width - WRAPPER_PADDING * 2;
            caption.set_position(WRAPPER_PADDING, container.y + container.height + WRAPPER_PADDING);
        }

        void update_indicator_position(bool initial = false)
        {
            // FIXME there are some troubles with layouting, in some cases we
            //       are here too early, in which case all the children are at
            //       (0|0), so we can easily check for that and come back later
            if (container.get_n_children() > 1
                && container.get_child_at_index(1).allocation.x1 < 1) {

                GLib.Timeout.add(FIX_TIMEOUT_INTERVAL, () => {
                    update_indicator_position(initial);
                    return false;
                }, GLib.Priority.DEFAULT);
                return;
            }

            float x, y;
            cur_icon.allocation.get_origin(out x, out y);

            if (initial) {
                indicator.visible = true;
                indicator.save_easing_state();
                indicator.set_easing_duration(0);
            }

            indicator.x = container.margin_left + (container.get_n_children() > 1 ? x : 0) - WRAPPER_PADDING;
            indicator.y = container.margin_top + y - WRAPPER_PADDING;

            if (initial) {
                indicator.restore_easing_state();
            }
            update_caption_text(initial);
        }

        void key_focus_out()
        {
            if (opened) {
                //FIXME: problem if layout swicher across witch window switcher shortcut
                close_switcher(get_timestamp());
            }
        }

        bool container_motion_event (MotionEvent event)
        {
            var actor = event.stage.get_actor_at_pos(PickMode.ALL, (int) event.x, (int) event.y);
            if (actor == null) {
                return true;
            }

            var selected = actor as WindowIcon;
            if (selected == null) {
                return true;
            }

            if (cur_icon != selected) {
                cur_icon = selected;
                update_indicator_position();
            }

            return true;
        }

        bool container_mouse_press (ButtonEvent event)
        {
            if (opened && event.button == Gdk.BUTTON_PRIMARY) {
                close_switcher(event.time);
            }

            return true;
        }

        bool key_release_event (KeyEvent event)
        {
            if ((get_current_modifiers() & modifier_mask) == 0) {
                close_switcher(event.time);
                return true;
            }

            switch (event.keyval) {
                case Key.Escape:
                    close_switcher(event.time);
                    return true;
            }

            return false;
        }

        Gdk.ModifierType get_current_modifiers ()
        {
            Gdk.ModifierType modifiers;
            double[] axes = {};
            Gdk.Display.get_default()
                .get_device_manager()
                .get_client_pointer()
                .get_state(Gdk.get_default_root_window(), axes, out modifiers);

            return modifiers;
        }

        bool keybinding_filter (KeyBinding binding)
        {
            // if it's not built-in, we can block it right away
            if (!binding.is_builtin()) {
                return true;
            }

            // otherwise we determine by name if it's meant for us
            var name = binding.get_name();

            return !(name == "switch-applications" || name == "switch-applications-backward"
                || name == "switch-windows" || name == "switch-windows-backward");
        }

        private uint32 get_timestamp() {
            var screen = wm.get_screen();
            return screen.get_display().get_current_time();
        }
    }
}

public Gala.PluginInfo register_plugin()
{
    return Gala.PluginInfo() {
        name = "Elementary Alt Tab Plus ver." + Gala.Plugins.AltTabPlus.SWITCHER_PLUGIN_VERSION,
        author = "Mark Story",
        plugin_type = typeof (Gala.Plugins.AltTabPlus.Main),
        provides = Gala.PluginFunction.WINDOW_SWITCHER,
        load_priority = Gala.LoadPriority.IMMEDIATE
    };
}
