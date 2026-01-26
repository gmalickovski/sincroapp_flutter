const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'lib/common/widgets/modern/schedule_task_sheet.dart');

try {
    let content = fs.readFileSync(filePath, 'utf8');
    let original = content;

    // 1. Fix Logic: endDate: null
    // We look for the 30 days duration in the daily default
    content = content.replace(
        /endDate:\s*_selectedDay\.add\(const\s+Duration\(days:\s*30\)\),/,
        'endDate: null, // Infinite recurrence'
    );

    // 2. Remove "Termina em" Label
    // Using Regex to match: const Text( "Termina em", style: ... ),
    content = content.replace(
        /const\s+Text\s*\(\s*"Termina em"[\s\S]*?style:[\s\S]*?\),[\s\S]*?const\s+SizedBox\(height:\s*8\),/g,
        '// Removed Termina em label'
    );

    // 3. Remove the Duration Chips Row (SingleChildScrollView)
    // We look for the SingleChildScrollView that contains _buildDurationChip
    const startMarker = 'SingleChildScrollView(';
    const durationChipMarker = '_buildDurationChip("1 Mês"';

    // Simple block removal strategy:
    // Find lines containing the duration chips and comment them out specifically
    // behaving like a surgeon instead of replacing a huge block blindly.

    // We'll replace the chips calls with comments.
    content = content.replace(/_buildDurationChip\("1 Mês",/g, '// _buildDurationChip("1 Mês",');
    content = content.replace(/_buildDurationChip\("6 Meses",/g, '// _buildDurationChip("6 Meses",');
    content = content.replace(/_buildDurationChip\("1 Ano",/g, '// _buildDurationChip("1 Ano",');

    // And the custom action chip
    content = content.replace(/ActionChip\s*\(\s*label:\s*Text\s*\(\s*_recurrenceRule\.endDate/g, '/* ActionChip( label: Text(_recurrenceRule.endDate');
    // We need to close the comment for the ActionChip. It ends with ),
    // It's safer to just replace the whole known structure if possible, or just hide the parent row if we could.
    // Let's try to match the whole SingleChildScrollView if we can identify it uniquely.

    // Regex for the whole SingleChildScrollView containing duration chips
    // It starts after the "Termina em" label (which we handled/removed above).
    // Let's try to match the specific content block used in the code:
    // SingleChildScrollView( scrollDirection: Axis.horizontal, child: Row( children: [ ... ] ) )

    // Easier approach: Replace the _buildRecurrenceRow body part that adds these widgets.
    // But we are in a script, so simple string replacement is best.

    if (content.includes('// Removed Termina em label')) {
        // If we successfully replaced the label, the next sibling is the SingleChildScrollView
        // We can just comment out the SingleChildScrollView start and end? No, unbalanced.
        // We will replace the entire lines related to the chips.
    }

    // Brute force removal of the chips block
    const chipsBlockRegex = /SingleChildScrollView\s*\(\s*scrollDirection:\s*Axis\.horizontal,\s*child:\s*Row\s*\(\s*children:\s*\[\s*\/\/ Removed "Nunca"[\s\S]*?_buildDurationChip\("1 Mês"[\s\S]*?children:\s*\[[\s\S]*?_buildDurationChip\("6 Meses"[\s\S]*?ActionChip\([\s\S]*?visualDensity: VisualDensity\.compact,\s*\),\s*],\s*\),\s*\),/m;

    // The previous regex is too complex and brittle.
    // Let's just comment out the calls inside the list.

    // Replace the ActionChip block end
    content = content.replace(/visualDensity: VisualDensity\.compact,\s*\),/g, 'visualDensity: VisualDensity.compact, ), */');

    if (content !== original) {
        fs.writeFileSync(filePath, content, 'utf8');
        console.log("SUCCESS: schedule_task_sheet.dart updated.");
    } else {
        console.log("WARNING: Patterns not found. Dump of target area:");
        // Debug: print around "Termina em"
        const idx = content.indexOf("Termina em");
        if (idx !== -1) {
            console.log(content.substring(idx - 50, idx + 200));
        } else {
            console.log("'Termina em' not found string-wise.");
        }
    }

} catch (e) {
    console.error("ERROR updating file:", e);
}
