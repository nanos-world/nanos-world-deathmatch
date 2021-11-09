var match_status = "";
var current_time = 0;
var had_scoreboard_change = false;

// Registers for ToggleVoice from Scripting
Events.Subscribe("ToggleVoice", function(name, enable) {
	const existing_span = document.querySelector(`.voice_chat#${name}`);

	if (enable) {
		if (existing_span)
			return;

		const span = document.createElement("span");
		span.classList.add("voice_chat");
		span.id = name;
		span.innerHTML = name;

		document.querySelector("#voice_chats").prepend(span);
	} else {
		if (!existing_span)
			return;

		existing_span.remove();
	}
});

// Registers for Notifications from Scripting
Events.Subscribe("AddNotification", function(message, time) {
	const span = document.createElement("span");
	span.classList.add("notification");
	span.innerHTML = message;

	document.querySelector("#notifications").prepend(span);

	setTimeout(function(span) {
		span.remove()
	}, time, span);
});

// Register for UpdateWeaponAmmo custom event (from Lua)
Events.Subscribe("UpdateWeaponAmmo", function(enable, clip, bag) {
	if (enable)
		document.querySelector("#weapon_ammo_container").style.display = "block";
	else
		document.querySelector("#weapon_ammo_container").style.display = "none";

	// Using JQuery, overrides the HTML content of these SPANs with the new Ammo values
	document.querySelector("#weapon_ammo_clip").innerHTML = clip;
	document.querySelector("#weapon_ammo_bag").innerHTML = bag;
});

// Register for UpdateHealth custom event (from Lua)
Events.Subscribe("UpdateHealth", function(health) {
	// Overrides the HTML content of the SPAN with the new health value
	document.querySelector("#health_current").innerHTML = health;

	// Bonus: make the background red when health below 25
	document.querySelector("#health_container").style.backgroundColor = health <= 25 ? "#ff05053d" : "#0000003d";
});

// Function to sort the scoreboard by score
function SortScoreboard() {
	// Invalidates the scoreboard_change cache
	had_scoreboard_change = false;

	// Gets the table
    const table = document.getElementById("scoreboard_tbody");
    let store = [];

	// Pushes all elements to a temp array
	for (let i = 0, len = table.rows.length; i < len; i++) {
        const row = table.rows[i];
        const score = parseInt(row.cells[2].innerText);

		if (!isNaN(score))
			store.push([score, row]);
    }

	// Sorts the temp array, using the score
    store.sort(function(x, y) {
        return y[0] - x[0];
    });

	// Append the elements to the DOM, sorted
    for (let i = 0, len = store.length; i < len; i++) {
        table.appendChild(store[i][1]);
    }

	// Fix the scoreboard at the top of the screen with the sorted data
    for (let i = 0; i < 10; i++) {
		let name = "";
		let score = "";

		if (i < store.length) {
			name = store[i][1].cells[1].innerText;
			score = store[i][1].cells[2].innerText;
		}

		const rank_entry = document.getElementById(`scoreboard_rank_entry_${i}`);

		const rank_entry_image = rank_entry.querySelector(".scoreboard_rank_image");
		rank_entry_image.innerHTML = name.substring(0, 3).toUpperCase();

		const rank_entry_score = rank_entry.querySelector(".scoreboard_rank_score");
		rank_entry_score.innerHTML = score;
	}
}

Events.Subscribe("UpdateMatchStatus", function(label, remaining_time) {
	match_status = label;
	current_time = remaining_time;
});

// Updates the screen match time and sorts the scoreboard at each 1 second
setInterval(function() {
	if (current_time > 0) {
		current_time--;
		
		const mins = ("00" + Math.floor(current_time / 60)).slice(-2);
		const seconds = ("00" + (current_time % 60)).slice(-2);

		document.querySelector("#match_status").innerHTML = `${match_status}${mins.toString()}:${seconds.toString()}`;
	}

	if (had_scoreboard_change)
		SortScoreboard();
}, 1000);

// Function to update a player's data
Events.Subscribe("UpdatePlayer", function(id, active, name, score, kills, deaths, ping) {
	had_scoreboard_change = true;
	const existing_scoreboard_entry = document.querySelector(`#scoreboard_entry_id${id}`);

	if (active) {
		// If the DOM exists, updates it
		if (existing_scoreboard_entry) {
			const scoreboard_ping = existing_scoreboard_entry.querySelector("td.scoreboard_ping");
			scoreboard_ping.innerHTML = ping;

			const scoreboard_score = existing_scoreboard_entry.querySelector("td.scoreboard_score");
			scoreboard_score.innerHTML = score;

			const scoreboard_kills = existing_scoreboard_entry.querySelector("td.scoreboard_kills");
			scoreboard_kills.innerHTML = kills;

			const scoreboard_deaths = existing_scoreboard_entry.querySelector("td.scoreboard_deaths");
			scoreboard_deaths.innerHTML = deaths;

			return;
		}

		// Otherwise, creates a new element and push to the scoreboard
		const scoreboard_entry_tr = document.createElement("tr");
		scoreboard_entry_tr.id = `scoreboard_entry_id${id}`;

		const scoreboard_entry_td_id = document.createElement("td");
		scoreboard_entry_td_id.className = "scoreboard_id";
		scoreboard_entry_td_id.innerHTML = id;
		scoreboard_entry_tr.appendChild(scoreboard_entry_td_id);

		const scoreboard_entry_td_name = document.createElement("td");
		scoreboard_entry_td_name.className = "scoreboard_name";
		scoreboard_entry_td_name.innerHTML = name;
		scoreboard_entry_tr.appendChild(scoreboard_entry_td_name);

		const scoreboard_entry_td_score = document.createElement("td");
		scoreboard_entry_td_score.className = "scoreboard_score";
		scoreboard_entry_td_score.innerHTML = score;
		scoreboard_entry_tr.appendChild(scoreboard_entry_td_score);

		const scoreboard_entry_td_kills = document.createElement("td");
		scoreboard_entry_td_kills.className = "scoreboard_kills";
		scoreboard_entry_td_kills.innerHTML = kills;
		scoreboard_entry_tr.appendChild(scoreboard_entry_td_kills);

		const scoreboard_entry_td_deaths = document.createElement("td");
		scoreboard_entry_td_deaths.className = "scoreboard_deaths";
		scoreboard_entry_td_deaths.innerHTML = deaths;
		scoreboard_entry_tr.appendChild(scoreboard_entry_td_deaths);

		const scoreboard_entry_td_ping = document.createElement("td");
		scoreboard_entry_td_ping.className = "scoreboard_ping";
		scoreboard_entry_td_ping.innerHTML = ping;
		scoreboard_entry_tr.appendChild(scoreboard_entry_td_ping);

		document.querySelector("#scoreboard_tbody").prepend(scoreboard_entry_tr);
	} else {
		if (!existing_scoreboard_entry)
			return;

		existing_scoreboard_entry.remove();
	}
});
