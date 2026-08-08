@using Airlinemgmtsystem
@model IEnumerable<Airlinemgmtsystem.FlightSeat>

@{
    ViewBag.Title = "Seat Selection";
    Layout = "~/Views/Shared/_Layout.cshtml";

    var passengers = ViewBag.Passengers as List<Airlinemgmtsystem.Passenger>;
    var seats = ViewBag.Seats as List<Airlinemgmtsystem.FlightSeat>;
    decimal baseFare = ViewBag.BaseFare != null ? (decimal)ViewBag.BaseFare : 0;
}

<div class="container mt-4">
    <div class="card shadow mb-4">
        <div class="card-header bg-primary text-white">
            <h3 class="mb-0">Seat Selection</h3>
        </div>
        <div class="card-body">
            <div class="alert alert-info">
                <div class="row">
                    <div class="col-md-4">
                        <strong>Flight Fare</strong><br />
                        ₹<span id="BaseFare">@baseFare.ToString("0.00")</span>
                    </div>
                    <div class="col-md-4">
                        <strong>Seat Charges</strong><br />
                        ₹<span id="SeatCharges">0.00</span>
                    </div>
                    <div class="col-md-4">
                        <strong>Total Amount</strong><br />
                        ₹<span id="TotalAmount">@baseFare.ToString("0.00")</span>
                    </div>
                </div>
            </div>

            <div class="card shadow mb-4">
                <div class="card-header bg-primary text-white">
                    <h5 class="mb-0">Select Seats</h5>
                </div>
                <div class="card-body">
                    <label for="Passenger">
                        <strong>Select Passenger</strong>
                    </label>

                    <select id="Passenger" class="form-control mb-4">
                        <option value="">-- Select Passenger --</option>
                        @if (passengers != null)
                        {
                            foreach (var p in passengers)
                            {
                                <option value="@p.PassengerID">
                                    @p.PassengerName
                                </option>
                            }
                        }
                    </select>

                    <div class="mb-3">
                        <span class="badge badge-success mr-2">Available</span>
                        <span class="badge badge-danger mr-2">Booked</span>
                        <span class="badge badge-primary mr-2">Selected</span>
                        <span class="badge badge-warning">Selected by another passenger</span>
                    </div>

                    <div class="row">
                        @if (seats != null)
                        {
                            foreach (var seat in seats)
                            {
                                int seatPrice = 300;

                                if (seat.SeatType == "Window")
                                {
                                    seatPrice = 800;
                                }
                                else if (seat.SeatType == "Aisle")
                                {
                                    seatPrice = 500;
                                }

                                string seatClass = seat.IsBooked
                                    ? "btn-danger"
                                    : "btn-success";

                                <div class="col-2 mb-3">
                                    <button type="button"
                                            class="btn @seatClass seatBtn w-100"
                                            data-seatid="@seat.SeatID"
                                            data-seat="@seat.SeatNumber"
                                            data-price="@seatPrice"
                                            data-booked="@seat.IsBooked.ToString().ToLower()"
                                            @(seat.IsBooked ? "disabled" : "")>
                                        @seat.SeatNumber
                                    </button>
                                </div>
                            }
                        }
                    </div>
                </div>
            </div>

            @using (Html.BeginForm("SeatSelection", "Booking", FormMethod.Post, new { id = "seatForm" }))
            {
                @Html.AntiForgeryToken()

                <div id="SeatContainer"></div>

                <input type="hidden"
                       id="FinalAmount"
                       name="FinalAmount"
                       value="@baseFare" />

                <button type="submit" class="btn btn-primary btn-lg">
                    Continue to Payment
                </button>
            }
        </div>
    </div>
</div>

<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>

<script>
var allocations = [];
var passengerColors = [
    "btn-primary",
    "btn-info",
    "btn-warning",
    "btn-secondary",
    "btn-dark"
];

$(".seatBtn").click(function () {
    var passenger = $("#Passenger").val();
    var passengerName = $("#Passenger option:selected").text().trim();

    if (!passenger) {
        alert("Please select a passenger first.");
        return;
    }

    var seatId = $(this).data("seatid");
    var seatNo = $(this).data("seat");
    var seatPrice = parseFloat($(this).data("price")) || 0;
    var currentButton = $(this);

    var existingPassengerSeat = allocations.find(function (x) {
        return String(x.passenger) === String(passenger);
    });

    if (existingPassengerSeat) {
        if (String(existingPassengerSeat.seat) === String(seatId)) {
            allocations = allocations.filter(function (x) {
                return String(x.passenger) !== String(passenger);
            });

            currentButton.removeClass(function (index, className) {
                return (className.match(/(^|\s)btn-\S+/g) || []).join(" ");
            }).addClass("btn-success");

            renderHidden();
            updateAmount();
            return;
        }

        alert("This passenger already has a seat selected. Select the same seat to remove it.");
        return;
    }

    var seatAlreadyAssigned = allocations.some(function (x) {
        return String(x.seat) === String(seatId);
    });

    if (seatAlreadyAssigned) {
        alert("This seat is already assigned to another passenger.");
        return;
    }

    var passengerIndex = $("#Passenger option").index(
        $("#Passenger option:selected")
    ) - 1;

    var colorClass = passengerColors[
        passengerIndex % passengerColors.length
    ];

    allocations.push({
        passenger: passenger,
        passengerName: passengerName,
        seat: seatId,
        seatNo: seatNo,
        price: seatPrice,
        color: colorClass
    });

    currentButton.removeClass("btn-success")
        .addClass(colorClass);

    renderHidden();
    updateAmount();
});

function renderHidden() {
    var html = "";

    allocations.forEach(function (x) {
        html += "<input type='hidden' name='passengerId' value='" + x.passenger + "' />";
        html += "<input type='hidden' name='seatId' value='" + x.seat + "' />";
    });

    $("#SeatContainer").html(html);
}

function updateAmount() {
    var baseFare = parseFloat($("#BaseFare").text()) || 0;
    var seatCharge = 0;

    allocations.forEach(function (x) {
        seatCharge += parseFloat(x.price) || 0;
    });

    var totalAmount = baseFare + seatCharge;

    $("#SeatCharges").text(seatCharge.toFixed(2));
    $("#TotalAmount").text(totalAmount.toFixed(2));
    $("#FinalAmount").val(totalAmount.toFixed(2));
}

$("#seatForm").submit(function (e) {
    var passengerCount = $("#Passenger option[value!='']").length;

    if (allocations.length !== passengerCount) {
        e.preventDefault();
        alert("Please select exactly one seat for every passenger.");
        return false;
    }

    var uniquePassengers = new Set();
    var uniqueSeats = new Set();

    allocations.forEach(function (x) {
        uniquePassengers.add(String(x.passenger));
        uniqueSeats.add(String(x.seat));
    });

    if (uniquePassengers.size !== passengerCount) {
        e.preventDefault();
        alert("Each passenger must have exactly one seat.");
        return false;
    }

    if (uniqueSeats.size !== allocations.length) {
        e.preventDefault();
        alert("Two passengers cannot select the same seat.");
        return false;
    }

    renderHidden();
    updateAmount();

    return true;
});

$(document).ready(function () {
    updateAmount();
});
</script>
