//  Copyright (C) 2017, Popye [sailor3101@gmail.com]
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

namespace Gala.Plugins.AltTabPlus
{
    class Utils
    {
        public static void icon_fade(Actor act, bool _in=true)
        {
            if (act == null) {
                return;
            }
            if (_in) {
                act.save_easing_state();
                act.set_easing_duration(200);
                act.opacity = 255;
                act.restore_easing_state();
            } else {
                act.save_easing_state();
                act.set_easing_duration(200);
                act.opacity = INACTIVE_ICON_OPACITY;
                act.restore_easing_state();
            }
        }
    }
}
