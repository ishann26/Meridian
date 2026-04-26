

const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());


app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

// TEST ROUTE
app.get("/", (req, res) => {
  res.send("Backend running 🚀");
});

// ROUTES (we will fill later)
app.use("/route", require("./routes/route"));
app.use("/predict", require("./routes/predict"));
app.use("/optimize", require("./routes/optimize"));
app.use("/agent", require("./routes/agent"));

const PORT = 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    status: "error",
    message: "Something went wrong"
  });
});