import { UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { StatusBarViewExtensionAbility } from '@kit.DeskTopExtensionKit';
import { Logger } from 'nextcloud';

const TAG = 'StatusBar/Ability';

export default class StatusBarView extends StatusBarViewExtensionAbility {
    onCreate() {
        Logger.Info(TAG, `onCreate`);
    }

    onSessionCreate(want: Want, session: UIExtensionContentSession) {
        Logger.Info(TAG, `onSessionCreate, want: ${want.abilityName}`);
        session.loadContent('statusbar/StatusBarPage');
    }

    onForeground() {
        Logger.Info(TAG, `onForeground`);
    }

    onBackground() {
        Logger.Info(TAG, `onBackground`);
    }

    onSessionDestroy(session: UIExtensionContentSession) {
        Logger.Info(TAG, `onSessionDestroy`);
    }

    onDestroy() {
        Logger.Info(TAG, `onDestroy`);
    }
}
