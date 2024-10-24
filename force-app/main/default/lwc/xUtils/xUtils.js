import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import pleaseSelectARecord from '@salesforce/label/c.X_PLEASE_SELECT_ONE_RECORD';
import noRecentUpdates from '@salesforce/label/c.X_PLEASE_UPDATE_ONE_RECORD';
import dataSavedSuccessfully from '@salesforce/label/c.X_DATA_SAVED_SUCCESSFULLY';
import dataNotSavedSuccessfully from '@salesforce/label/c.X_DATA_NOT_SAVED_SUCCESSFULLY';
import commonSuccess from '@salesforce/label/c.COMMON_SUCCESS';
import commonToastInfoTitle from '@salesforce/label/c.INF_COMMON_TOAST_INFO_TITLE';
import commonToastErrorTitle from '@salesforce/label/c.ERR_COMMON_TOAST_ERROR_TITLE';
import deleteModalWarning from '@salesforce/label/c.XDELETE_MODAL_WARNING';
import uploadFile from '@salesforce/label/c.XUPLOAD_FILE';
import commonNext from '@salesforce/label/c.COMMON_NEXT';
import commonMap from '@salesforce/label/c.XCOMMON_MAP';
import commonOr from '@salesforce/label/c.XCOMMON_OR';
import requireFieldsMissing from '@salesforce/label/c.REQUIRED_FIELDS_ARE_MISSING';
import createNewMapping from '@salesforce/label/c.XCREATE_NEW_MAPPING';
import chooseExisting from '@salesforce/label/c.XCHOOSE_EXISTING';
import editRecord from '@salesforce/label/c.XEDIT_RECORD';
import deleteRecord from '@salesforce/label/c.XDELETE_RECORD';
import commonOk from '@salesforce/label/c.COMMON_OK';
import commonCopy from '@salesforce/label/c.COMMON_CLONE';
import commonUndo from '@salesforce/label/c.XCOMMON_UNDO';
import commonRedo from '@salesforce/label/c.XCOMMON_REDO';
import commonEdit from '@salesforce/label/c.COMMON_EDIT';
import commonCancel from '@salesforce/label/c.COMMON_CANCEL';
import commonSave from '@salesforce/label/c.COMMON_SAVE';
import commonDelete from '@salesforce/label/c.COMMON_DELETE';
import commonRefresh from '@salesforce/label/c.XCOMMON_REFRESH';
import csvUpload from '@salesforce/label/c.XCSV_UPLOAD';
import importCsv from '@salesforce/label/c.XIMPORT_CSV';
import exportCsv from '@salesforce/label/c.XEXPORT_CSV';
import addRow from '@salesforce/label/c.XADD_ROW';
import lookupField from '@salesforce/label/c.CSV_LOOKUP_FIELD';
import lookupType from '@salesforce/label/c.CSV_LOOKUP_TYPE';
import targetField from '@salesforce/label/c.CSV_TARGET_FIELD';
import targetObject from '@salesforce/label/c.CSV_TARGET_OBJECT';
import header from '@salesforce/label/c.CSV_HEADER';
import createTemplate from '@salesforce/label/c.CSV_CREATE_TEMPLATE';
import selectTemplate from '@salesforce/label/c.CSV_SELECT_TEMPLATE';
import close from '@salesforce/label/c.COMMON_CLOSE';
import back from '@salesforce/label/c.COMMON_BACK';
import importFields from '@salesforce/label/c.CSV_IMPORT_FIELDS';
import preview from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_SUB_TITLE_PREVIEW';
import commonImport from '@salesforce/label/c.CSV_IMPORT';
import csv from '@salesforce/label/c.XCSV';
import csvUploadYourFile from '@salesforce/label/c.CSV_UPLOAD_FILE';
import createMapFields from '@salesforce/label/c.CSV_CREATE_MAP';
import groupBy from '@salesforce/label/c.CSV_GROUP_BY';
import reviewError from '@salesforce/label/c.CSV_REVIEW_ERROR';
import csvImportSuccess from '@salesforce/label/c.CSV_SUCCESS_IMPORT_DATA';
import csvNoMapping from '@salesforce/label/c.CSV_NO_MAPPING';
import existingTemplate from '@salesforce/label/c.CSV_EXISTING_TEMPLATE';
import noTemplate from '@salesforce/label/c.CSV_NO_TEMPLATE';
import csvPreviewMapping from '@salesforce/label/c.CSV_PREVIEW_MAPPING';
import csvTopRows from '@salesforce/label/c.CSV_TOP_ROWS';
import saveAndMap from '@salesforce/label/c.CSV_SAVE_AND_MAP';
import stayOnList from '@salesforce/label/c.X_STAY_ON_THIS_LIST';
import discardChanges from '@salesforce/label/c.X_DISCARD_CHANGES';
import warningMessage from '@salesforce/label/c.X_REFRESH_WARNING';
import editingItems from '@salesforce/label/c.X_EDITING_ITEMS';
import csvNoObjectSelected from '@salesforce/label/c.CSV_NO_OBJECT';
import onlyCSVCanBeUploaded from '@salesforce/label/c.CSV_ONLY_CSV_ERROR';
import csvExportWarningHeading from '@salesforce/label/c.CSV_EXPORT_ITEMS';
import csvExportWarning from '@salesforce/label/c.CSV_EXPORT_WARNING';
import csvNoGroupByFound from '@salesforce/label/c.CSV_NO_GROUP_BY_FOUND';
import supportedFile from '@salesforce/label/c.CSV_SUPPORTED_FILE';


const showToastMessage = (ref,title,message,variant) => {
    const event = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
    });
    ref.dispatchEvent(event);
}

const idGenerator = (prefix='_') => {
    function* generator(prefix='_') {
      let i = 0;
      while (true) {
        yield prefix + i;
        i++;
      }
    }
    return generator(prefix);
}
const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    dataNotSavedSuccessfully,
    commonSuccess,
    commonToastInfoTitle,
    commonToastErrorTitle,
    dataSavedSuccessfully,
    pleaseSelectARecord,
    deleteModalWarning,
    noRecentUpdates,
    createNewMapping,
    commonNext,
    commonMap,
    commonOr,
    commonCancel,
    commonDelete,
    commonRefresh,
    chooseExisting,
    deleteRecord,
    editRecord,
    commonOk,
    requireFieldsMissing,
    commonUndo,
    commonRedo,
    commonSave,
    commonCopy,
    commonEdit,
    csvUpload,
    uploadFile,
    addRow,
    csv,
    lookupField,
    lookupType,
    targetField,
    targetObject,
    header,
    createTemplate,
    selectTemplate,
    close,
    back,
    importFields,
    preview,
    commonImport,
    csvUploadYourFile,
    createMapFields,
    importCsv,
    exportCsv,
    groupBy,
    reviewError,
    csvImportSuccess,
    csvNoMapping,
    existingTemplate,
    noTemplate,
    csvPreviewMapping,
    csvTopRows,
    saveAndMap,
    stayOnList,
    editingItems,
    warningMessage,
    discardChanges,
    csvNoObjectSelected,
    onlyCSVCanBeUploaded,
    csvExportWarning,
    csvExportWarningHeading,
    csvNoGroupByFound,
    supportedFile
};

const reduceErrors = (errors) => {
    if (!Array.isArray(errors)) {
        errors = [errors];
    }
    return (
        errors.filter((error) => !!error)
            .map((error) => {
                if (Array.isArray(error.body)) {
                    return error.body.map((e) => e.message);
                }
                else if (error.body.pageErrors && typeof error.body.pageErrors[0].message === 'string') {                    
                    return error.body.pageErrors[0].message;
                }
                else if (error.body && typeof error.body.message === 'string') {                    
                    return error.body.message;
                }
                else if (typeof error.message === 'string') {
                    return error.message;
                }
                return error.statusText;
            })
            .reduce((prev, curr) => prev.concat(curr), [])
            .filter((message) => !!message)
    );
}
export {idGenerator,showToastMessage, labels as xLabelService,reduceErrors}