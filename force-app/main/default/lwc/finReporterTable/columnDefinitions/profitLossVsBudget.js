// wrapped in a function to avoid references modifying this data.
import TIMEZONE from "@salesforce/i18n/timeZone";
import Labels from "../labels";
import { LabelService } from "c/utils";

const profitLossVsBudget = () => {
    return [{
        label: Labels.INF_REPORT_NUMBER,
        fieldName: 'reportLink',
        type: 'customUrl',
        sortable: true,
        initialWidth: 160,
        typeAttributes: {
            label: {
                fieldName: 'reportName'
            },
            recordName: {
                fieldName: 'reportName'
            },
            showLink: {
                fieldName: 'showReportName'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left',
            disabled: true,
        }
    }, {
        label: LabelService.accountingHomeLedger,
        fieldName: 'ledgerLink',
        type: 'url',
        sortable: true,
        initialWidth: 130,
        typeAttributes: {
            label: {
                fieldName: 'ledgerName'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    },{
        label: LabelService.commonCurrency,
        fieldName: 'currency',
        type: 'text',
        sortable: true,
        initialWidth: 100,
        typeAttributes: {
            label: {
                fieldName: 'currency'
            },
            target: self
        },
        cellAttributes: {
            alignment: 'left'
        }
    },{
        label: LabelService.commonBudgetLedger,
        fieldName: 'budgetLedgerLink',
        type: 'url',
        sortable: true,
        initialWidth: 140,
        typeAttributes: {
            label: {
                fieldName: 'budgetLedgerName'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonStartPeriod,
        fieldName: 'startPeriodLink',
        type: 'url',
        sortable: true,
        initialWidth: 120,
        typeAttributes: {
            label: {
                fieldName: 'startPeriodName'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonEndPeriod,
        fieldName: 'endPeriodLink',
        type: 'url',
        sortable: true,
        initialWidth: 120,
        typeAttributes: {
            label: {
                fieldName: 'endPeriodName'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonGLVariable + ' 1',
        fieldName: 'glav1Link',
        type: 'url',
        sortable: true,
        initialWidth: 130,
        typeAttributes: {
            label: {
                fieldName: 'glav1Name'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonGLVariable + ' 2',
        fieldName: 'glav2Link',
        type: 'url',
        sortable: true,
        initialWidth: 130,
        typeAttributes: {
            label: {
                fieldName: 'glav2Name'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonGLVariable + ' 3',
        fieldName: 'glav3Link',
        type: 'url',
        sortable: true,
        initialWidth: 130,
        typeAttributes: {
            label: {
                fieldName: 'glav3Name'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonGLVariable + ' 4',
        fieldName: 'glav4Link',
        type: 'url',
        sortable: true,
        initialWidth: 130,
        typeAttributes: {
            label: {
                fieldName: 'glav4Name'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonStatus,
        fieldName: 'status',
        type: 'text',
        sortable: true,
        initialWidth: 100,
        typeAttributes: {
            label: {
                fieldName: 'status'
            },
            target: self
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: Labels.INF_COMPLETED_DATE_OR_TIME,
        fieldName: 'completedDateTime',
        type: 'date',
        sortable: true,
        initialWidth: 180,
        typeAttributes: {
            label: {
                fieldName: 'completedDateTime'
            },
            target: self,
            month: '2-digit',
            day: '2-digit',
            hour: "2-digit",
            minute: "2-digit",
            year: 'numeric',
            timeZone: TIMEZONE
        },
        cellAttributes: {
            alignment: 'left'
        }
    }, {
        label: LabelService.commonCreatedBy,
        fieldName: 'createByLink',
        type: 'url',
        sortable: true,
        initialWidth: 140,
        typeAttributes: {
            label: {
                fieldName: 'createByName'
            },
            target: '_blank'
        },
        cellAttributes: {
            alignment: 'left'
        }
    }]
};

export default profitLossVsBudget;