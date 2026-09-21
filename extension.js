import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import { Extension, gettext as _ } from 'resource:///org/gnome/shell/extensions/extension.js';

import { xClock } from './Clock.js';
import { connectClick } from './compat.js';

const debug = false;
function lg(s) {
	if (debug) console.log("===cairo-clock===>" + s);
}

const Indicator = GObject.registerClass(
	class Indicator extends PanelMenu.Button {
		_init(size) {
			super._init(0.0, _('Cairo Clock'), true);	//不要菜单

			this._size		  = size;
			this.pop_per_hour = false;	//整点弹出报时。

			this.add_child(new St.Icon({
				icon_name : 'org.gnome.clocks-symbolic',
				style_class : 'system-status-icon',
			}));

			this.clock = new xClock(size);
			Main.layoutManager.addChrome(this.clock);
			this.clock.visible = false;

			this.width = 50;
			this._update_style();
			connectClick(this, (button, state) => {
				const altkey  = state & Clutter.ModifierType.MOD1_MASK;
				const ctrlkey = state & Clutter.ModifierType.CONTROL_MASK;
				if (altkey) {
					this.pop_per_hour = !this.pop_per_hour;
					this._update_style();
					return;
				}
				if (ctrlkey) {
					this.alarm();
					return;
				}
				const [x, y] = global.get_pointer();
				this.clock.set_position(x - this._size / 2 + 10, y + 30);
				this.clock.visible = !this.clock.visible;
				this.ease_effect(this.clock);
			});
		}

		_update_style() {  // Clutter.Color 已移除，用样式表设置背景色。
			this.set_style(this.pop_per_hour ? 'background-color: #C98A38;' : null);
		}

		ease_effect(a) {  //直线位置动画，AnimationMode 只是时间间隔的变化。
			let monitor = Main.layoutManager.primaryMonitor;
			let newX, newOpacity, newScale;
			const isV	   = a.visible;
			const [px, py] = a.get_position();
			if (isV) {	//出现。
				a.set_scale(0.1, 0.1);
				a.set_pivot_point(0.5, 0.5);  //旋转等的中心
				a.rotation_angle_z = 360;
				a.opacity		   = 10;
				newX			   = px;
				newOpacity		   = 255;
				newScale		   = 1;
			} else {  //消失。
				newOpacity = 10;
				newScale   = 0.4;
				newX	   = monitor.width - this._size * newScale;
				a.visible  = true;	//强制显示，以产生动态。
			}

			a.ease({
				x : newX,
				scale_x : newScale,
				scale_y : newScale,
				opacity : newOpacity,
				rotation_angle_z : 0,
				duration : 1000,
				mode : Clutter.AnimationMode.EASE_OUT_BOUNCE,
				//~ exponentially decaying parabolic (bounce) 指数衰减抛物线（反弹）
				onComplete : () => {
					if (!isV) a.visible = false;  //恢复应该的状态。
					a.opacity = 255;  //及时恢复透明度。
					a.set_scale(1, 1);	//恢复比率，否则闹钟变小。
					a.set_position(px, py);	 //恢复位置，否则闹钟乱跑。
					Main.layoutManager._queueUpdateRegions();
					//改变scale，导致鼠标穿越。强制刷新。Simon says.
				}
			});
		};

		alarm() {
			const player = global.display.get_sound_player();
			player.play_from_theme('complete', 'countdown', null);
			this.clock.visible = true;
			this.clock.swing();
		}

		destroy() {
			if (this.clock) {
				Main.layoutManager.removeChrome(this.clock);
				this.clock.destroy();
				this.clock = null;
			}
			super.destroy();  // Extension point conflict if no destroy.
		}
	});

export default class CairoClockExtension extends Extension {
	enable() {
		lg("start");
		const size	   = Math.floor(Main.layoutManager.primaryMonitor.height / 4);
		this._indicator = new Indicator(size);
		Main.panel.addToStatusArea(this.uuid, this._indicator);

		this._lastFired = -1;  //同一分钟内只响一次。
		this._timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 10, () => {
			const [h, m] = this._indicator.clock.get_alarm();
			const d0	 = new Date();
			const m0	 = d0.getMinutes();
			if (this._lastFired == m0) return GLib.SOURCE_CONTINUE;

			if (h !== null && m !== null && h % 12 == d0.getHours() % 12 && m == m0) {
				this._lastFired = m0;
				this._indicator.alarm();
			} else if (this._indicator.pop_per_hour && m0 == 0) {  //整点弹出报时
				this._lastFired = m0;
				this._indicator.alarm();
			}
			return GLib.SOURCE_CONTINUE;
		});
	}

	disable() {
		lg("stop");
		if (this._timeoutId) {
			GLib.Source.remove(this._timeoutId);
			this._timeoutId = null;
		}
		this._indicator?.destroy();
		this._indicator = null;
	}
}
