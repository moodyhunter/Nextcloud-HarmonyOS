import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { Logger } from 'nextcloud';
import { UIContext } from '@ohos.arkui.UIContext';

const TAG = 'utils/PermissionManager';

export class PermissionManager {
    static async RequestPermission(context: UIContext, perms: Permissions[]): Promise<boolean> {
        let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
        Logger.Warn(TAG, `requestPermission for permissions: ${perms}`);

        let toGrant = await PermissionManager.getPermissionsToGrant(atManager, perms);
        if (toGrant.length === 0) {
            Logger.Info(TAG, `requestPermission success, all permissions already granted`);
            return true;
        }

        let result = await atManager.requestPermissionsFromUser(context.getHostContext()!, toGrant);

        let leftoverPermissions: Permissions[] = [];
        for (let i = 0; i < result.permissions.length; i++) {
            let rPerm = result.permissions[i];
            let rResult = result.authResults[i];
            let isGranted = rResult == abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
            if (!isGranted) {
                leftoverPermissions.push(rPerm as Permissions);
            }
        }

        if (leftoverPermissions.length == 0) {
            Logger.Info(TAG, `requestPermission success: ${toGrant}`);
            return true;
        }

        Logger.Warn(TAG, `requestPermission fail, ${leftoverPermissions}, requesting to open settings`);
        context.showAlertDialog({ message: '需要开启权限才能使用全部功能' });
        await atManager.requestPermissionOnSetting(context.getHostContext()!, leftoverPermissions);
        return false;
    }

    /**
     * Verify if the permission is granted
     * @param permission
     * @returns Promise<Permissions[]> permissions that are NOT granted
     */
    private static async getPermissionsToGrant(atManager: abilityAccessCtrl.AtManager, permission: Permissions[]): Promise<Permissions[]> {
        let bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);

        let verifySinglePermission = async (perm: Permissions): Promise<boolean> => {
            try {
                let grantStatus = await atManager.verifyAccessToken(bundleInfo.appInfo.accessTokenId, perm);
                Logger.Debug(TAG, `verifyPermission for ${perm}, grantStatus: ${grantStatus}`);
                return grantStatus == abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
            } catch (error) {
                Logger.Error(TAG, `verifyPermission exception for ${perm}, err->${JSON.stringify(error)}`);
                return false;
            }
        };

        let notGrantedPermissions: Permissions[] = [];
        for (let perm of permission) {
            if (!await verifySinglePermission(perm)) {
                notGrantedPermissions.push(perm);
            }
        }

        Logger.Info(TAG, `verifyPermission, not granted permissions: ${notGrantedPermissions}`);
        return notGrantedPermissions;
    }
}
