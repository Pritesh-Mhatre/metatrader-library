/************************************************
* Contains inter process communication details.
*
* Author: Pritesh Mhatre
************************************************/

/* Windows separator */
static string WIN_SEPARATOR = "\\";

/* Linux/unix separator */
static string UNIX_SEPARATOR = "/";

/* Inter process communication directory */
static string IPC_DIR = "autotrader";

/* Directory that contains input files for AutoTrader */
static string INPUT_DIR = IPC_DIR + WIN_SEPARATOR + "input";

/* Directory that contains output files from AutoTrader */
static string OUTPUT_DIR = IPC_DIR + WIN_SEPARATOR + "output";

/* AutoTrader commands */
static string COMMANDS_FILE = INPUT_DIR + WIN_SEPARATOR + "commands.csv";

/* Portfolio orders */
string getPortfolioOrdersFile(string pseudoAccount) {
	return OUTPUT_DIR + WIN_SEPARATOR + pseudoAccount + "-orders.csv";
}

/* Portfolio positions */
string getPortfolioPositionsFile(string pseudoAccount) {
	return OUTPUT_DIR + WIN_SEPARATOR + pseudoAccount + "-positions.csv";
}

/* Portfolio margins */
string getPortfolioMarginsFile(string pseudoAccount) {
	return OUTPUT_DIR + WIN_SEPARATOR + pseudoAccount + "-margins.csv";
}