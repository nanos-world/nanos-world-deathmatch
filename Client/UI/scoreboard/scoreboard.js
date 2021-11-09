document.addEventListener("DOMContentLoaded", function(event) {
	// Inserts the scoreboard
	const body = document.querySelector(`body`);

	body.insertAdjacentHTML("afterbegin", `
		<div id="scoreboard">
			<table>
				<thead>
					<tr id="scoreboard_header">
						<th>ID</th>
						<th>player</th>
						<th id="scoreboard_score">score</th>
						<th>kills</th>
						<th>deaths</th>
						<th>ping</th>
					</tr>
				</thead>
				<tbody id="scoreboard_tbody">
					<!-- <tr id="scoreboard_entry_id1"><td class="scoreboard_id">1</td><td class="scoreboard_name">SyedMuhammad</td><td class="scoreboard_ping">100</td></tr> -->
				</tbody>
			</table>
		</div>
	`);
});

function ToggleScoreboard(enable) {
	const scoreboard = document.querySelector("#scoreboard");

	if (enable)
		scoreboard.style.display = "block";
	else
		scoreboard.style.display = "none";
}

Events.Subscribe("ToggleScoreboard", ToggleScoreboard);