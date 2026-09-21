import Clutter from 'gi://Clutter';

// GNOME 48+ 的手势框架接管了按键事件，actor 不再收到 button-press-event，
// 所以有 Clutter.ClickGesture 就用手势，没有就退回旧信号。
// callback(button, modifier_state)
export function connectClick(actor, callback) {
	if (Clutter.ClickGesture) {
		for (const button of [ Clutter.BUTTON_PRIMARY, Clutter.BUTTON_SECONDARY ]) {
			const gesture = new Clutter.ClickGesture({ required_button : button });
			gesture.set_recognize_on_press(true);
			gesture.connect('recognize', g => {
				const event = g.get_point_event(0);
				callback(g.get_button(), event ? event.get_state() : global.get_pointer()[2]);
			});
			actor.add_action(gesture);
		}
		return;
	}
	actor.connect('button-press-event', (a, event) => {
		callback(event.get_button(), event.get_state());
		return Clutter.EVENT_STOP;
	});
}
