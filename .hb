@using Airlinemgmtsystem
@model IEnumerable<Airlinemgmtsystem.FlightSeat>

@{
    ViewBag.Title = "Seat Selection";
    Layout = "~/Views/Shared/_Layout.cshtml";

    var passengers = ViewBag.Passengers as List<Airlinemgmtsystem.Passenger>;
    var seats = ViewBag.Seats as List<Airlinemgmtsystem.FlightSeat>;
    decimal baseFare = ViewBag.BaseFare != null ? (decimal)ViewBag.BaseFare : 0;

    // Dictionary<passengerId, seatId> already saved in Session from earlier picks
    var seatMap = ViewBag.SeatMap as Dictionary<int, int> ?? new Dictionary<int, int>();
}

<div class="container mt-4">

    @if (TempData["Message"] != null)
    {
        <div class="alert alert-danger">
            @TempData["Message"]
        </div>
    }

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

    <div class="card shadow mb-3">
        <div class="card-header bg-primary text-white">
            <h3 class="mb-0">Select Seats</h3>
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
                        <option value="@p.PassengerID">@p.PassengerName</option>
                    }
                }
            </select>

            <div class="mb-3">
                <span class="badge badge-success mr-2">Available</span>
                <span class="badge badge-primary mr-2">Selected</span>
                <span class="badge badge-danger">Booked</span>
            </div>

            <div class="alert alert-secondary">
                <strong>Important:</strong>
                Select exactly one seat for each passenger, one at a time.
                A seat selected by one passenger cannot be selected by another passenger.
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

                        bool alreadyAssigned = seatMap.ContainsValue(seat.SeatID);
                        string seatClass = seat.IsBooked ? "btn-danger" : (alreadyAssigned ? "btn-primary" : "btn-success");

                        <div class="col-2 mb-3">
                            <button type="button"
                                    class="btn @seatClass seatBtn w-100"
                                    data-seatid="@seat.SeatID"
                                    data-seat="@seat.SeatNumber"
                                    data-price="@seatPrice"
                                    data-booked="@seat.IsBooked.ToString().ToLower()"
                                    title="@seat.SeatType Seat (+₹@seatPrice)"
                                    @(seat.IsBooked ? "disabled" : "")>
                                @seat.SeatNumber
                            </button>
                        </div>
                    }
                }
            </div>

            <hr />

            @using (Html.BeginForm("ConfirmSeats", "Booking", FormMethod.Post, new { id = "seatForm" }))
            {
                @Html.AntiForgeryToken()

                <button type="submit" class="btn btn-primary btn-lg mt-3">
                    Continue to Payment
                </button>
            }
        </div>
    </div>
</div>

<style>
    .seatBtn {
        min-height: 45px;
        font-weight: 600;
    }
</style>

<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>

<script>
    var antiForgeryToken = $('input[name="__RequestVerificationToken"]').val();

    function getPassengerName(passengerId) {
        return $("#Passenger option[value='" + passengerId + "']").text().trim();
    }

    $(".seatBtn").click(function () {
        var passenger = $("#Passenger").val();

        if (!passenger) {
            alert("Please select a passenger first.");
            return;
        }

        var seatId = $(this).data("seatid");
        var seatNo = $(this).data("seat");
        var currentButton = $(this);

        // Ask server to save this passenger -> seat assignment in Session.
        $.ajax({
            url: '@Url.Action("AssignSeat", "Booking")',
            type: "POST",
            data: {
                passengerId: passenger,
                seatId: seatId,
                __RequestVerificationToken: antiForgeryToken
            },
            success: function (response) {
                if (!response.success) {
                    alert(response.message || "Could not assign this seat.");
                    return;
                }

                renderSeatMap(response.seatMap);
                updateAmount(response.baseFare, response.seatCharge, response.totalAmount);

                // Auto-advance to the next passenger without a seat yet.
                if (response.nextPassengerId) {
                    $("#Passenger").val(response.nextPassengerId);
                } else {
                    $("#Passenger").val("");
                }
            },
            error: function () {
                alert("Something went wrong while assigning the seat. Please try again.");
            }
        });
    });

    function renderSeatMap(seatMap) {
        // seatMap: { passengerId: seatId, ... } returned fresh from the server
        var assignedSeatIds = Object.values(seatMap).map(String);

        $(".seatBtn").each(function () {
            var button = $(this);
            var seatId = String(button.data("seatid"));
            var booked = button.data("booked");

            if (String(booked) === "true") {
                button.removeClass().addClass("btn btn-danger seatBtn w-100").prop("disabled", true);
                return;
            }

            if (assignedSeatIds.indexOf(seatId) !== -1) {
                button.removeClass().addClass("btn btn-primary seatBtn w-100");
            } else {
                button.removeClass().addClass("btn btn-success seatBtn w-100");
            }
        });
    }

    function updateAmount(baseFare, seatCharge, totalAmount) {
        $("#BaseFare").text(parseFloat(baseFare).toFixed(2));
        $("#SeatCharges").text(parseFloat(seatCharge).toFixed(2));
        $("#TotalAmount").text(parseFloat(totalAmount).toFixed(2));
    }

    $("#seatForm").submit(function (e) {
        // Server (ConfirmSeats) does the real validation against Session;
        // this is just a friendly client-side pre-check.
        var passengerCount = $("#Passenger option[value!='']").length;
        var assignedCount = $(".seatBtn.btn-primary").length;

        if (assignedCount !== passengerCount) {
            e.preventDefault();
            alert("Please select exactly one seat for every passenger.");
            return false;
        }

        return true;
    });
</script>
