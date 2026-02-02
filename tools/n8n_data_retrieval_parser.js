/**
 * N8n Data Retrieval - Parse Date Range
 * Converte time_range (next_week, overdue, etc.) em datas para filtro Supabase
 */

// === INPUTS ===
const routerOutput = items[0].json;
const params = routerOutput.params || routerOutput;
const timeRange = params.time_range || 'today';
const entities = params.entities || ['task'];

const webhook = $('Webhook (SincroApp)').item.json;
const userId = webhook.body?.userId;
const currentDateStr = webhook.body?.context?.currentDate;

// Parse current date from context
const now = currentDateStr ? new Date(currentDateStr) : new Date();
const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

// === DATE CALCULATION HELPERS ===
function startOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function endOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59);
}

function addDays(date, days) {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
}

function getNextMonday(date) {
    const d = new Date(date);
    const day = d.getDay();
    const diff = day === 0 ? 1 : 8 - day; // se domingo, próx é amanhã
    d.setDate(d.getDate() + diff);
    return startOfDay(d);
}

function getEndOfWeek(startMonday) {
    return endOfDay(addDays(startMonday, 6)); // domingo
}

function getEndOfMonth(date) {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59);
}

function getStartOfMonth(date) {
    return new Date(date.getFullYear(), date.getMonth(), 1);
}

// === CALCULATE DATE RANGE ===
let startDate = null;
let endDate = null;
let filterCompleted = false; // false = show pending only
let filterType = timeRange;
let humanDescription = '';

switch (timeRange) {
    case 'today':
        startDate = startOfDay(today);
        endDate = endOfDay(today);
        humanDescription = 'hoje';
        break;

    case 'tomorrow':
        const tomorrow = addDays(today, 1);
        startDate = startOfDay(tomorrow);
        endDate = endOfDay(tomorrow);
        humanDescription = 'amanhã';
        break;

    case 'this_week':
        startDate = startOfDay(today);
        const sunday = addDays(today, 7 - today.getDay());
        endDate = endOfDay(sunday);
        humanDescription = 'esta semana';
        break;

    case 'next_week':
        const nextMonday = getNextMonday(today);
        startDate = startOfDay(nextMonday);
        endDate = getEndOfWeek(nextMonday);
        humanDescription = 'semana que vem';
        break;

    case 'this_month':
        startDate = startOfDay(today);
        endDate = getEndOfMonth(today);
        humanDescription = 'este mês';
        break;

    case 'next_two_weeks':
    case 'next_2_weeks':
        startDate = startOfDay(today);
        endDate = endOfDay(addDays(today, 14));
        humanDescription = 'próximas duas semanas';
        break;

    case 'overdue':
        startDate = null; // sem limite inferior
        endDate = startOfDay(today); // antes de hoje
        filterCompleted = false;
        humanDescription = 'atrasadas';
        break;

    case 'pending':
    case 'all_pending':
        startDate = null;
        endDate = null;
        filterCompleted = false;
        humanDescription = 'pendentes';
        break;

    default:
        // Default to today
        startDate = startOfDay(today);
        endDate = endOfDay(today);
        humanDescription = 'hoje';
}

// === BUILD SUPABASE FILTER STRING ===
let filterParts = [`user_id=eq.${userId}`];

if (startDate && timeRange !== 'overdue') {
    filterParts.push(`due_date=gte.${startDate.toISOString()}`);
}

if (endDate) {
    if (timeRange === 'overdue') {
        filterParts.push(`due_date=lt.${endDate.toISOString()}`);
    } else {
        filterParts.push(`due_date=lte.${endDate.toISOString()}`);
    }
}

if (!filterCompleted) {
    filterParts.push('completed=eq.false');
}

const supabaseFilter = filterParts.join('&');

// === OUTPUT ===
return {
    userId: userId,
    entities: entities,
    timeRange: timeRange,
    humanDescription: humanDescription,
    startDate: startDate?.toISOString() || null,
    endDate: endDate?.toISOString() || null,
    filterCompleted: filterCompleted,
    supabaseFilter: supabaseFilter,
    originalQuestion: webhook.body?.question || '',
    router_usage: routerOutput.router_usage
};
