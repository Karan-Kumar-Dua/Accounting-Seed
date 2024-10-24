import {NotificationService, ModalLightningElement, LabelService} from "c/utils";
import Labels from "./labels";
export default class BdcImportFileWizard extends ModalLightningElement {
    labels = {...LabelService, ...Labels};
    step = 'selectFile';
    importFileDto = { isValid: false };
    nextStepBtnLabel = LabelService.commonNext;

    get currentStep() {
        return this.step;
    }
    get isSelectFileStep() {
        return this.step === 'selectFile';
    }
    get isChangeSettingsStep() {
        return this.step === 'changeSettings';
    }

    handleCloseWizard() {
        this.dispatchEvent(new CustomEvent('close', { bubbles: true }));
    }

    goToNextStep() {
        if (this.isSelectFileStep) {
            let selectFileCmp = this.template.querySelector('c-bdc-import-file-wizard-select-file');
            selectFileCmp.resolveNextStep();
        }
        else if (this.isChangeSettingsStep) {
            let changeSettingsCmp = this.template.querySelector('c-bdc-import-file-wizard-change-settings');
            changeSettingsCmp.resolveNextStep();
        }
    }

    handleNextStepSuccess(event) {
        if (this.isSelectFileStep) {
            this.importFileDto = event.detail;
            this.step = 'changeSettings';
            this.nextStepBtnLabel = LabelService.commonImport;
        }
        else if (this.isChangeSettingsStep) {
            this.handleCloseWizard();
            NotificationService.displayToastMessage(
                this,
                event.detail,
                Labels.INF_IMPORT_COMPLETE
            );
            /* eslint-disable-next-line no-eval
               eval("$A.get('e.force:refreshView').fire();");
            */
            this.dispatchEvent(new CustomEvent('refresh'));
        }
    }

    handleFocusNextBtn() {
        const nextStepBtn = this.template.querySelector('lightning-button[data-id="nextStepBtn"]');
        nextStepBtn && nextStepBtn.focus();
    }
}