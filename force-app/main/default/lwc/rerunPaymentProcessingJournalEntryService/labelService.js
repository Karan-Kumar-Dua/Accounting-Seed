import reRunBatchInProgress from '@salesforce/label/c.CRDKNX_RE_RUN_PROCESS_IS_IN_PROGRESS';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    reRunBatchInProgress
}
export {labels};