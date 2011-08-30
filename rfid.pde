/*
Arduino RFID Door Lock
ID-12/ID-12 RFID reader

Based on 125khz RFID codes


Created 2011-08-16
by Ståle Semb Hauknes <stale.hauknes@gmail.com>


This code is based on:
http://www.arduino.cc/playground/Learning/PRFID
http://www.arduino.cc/playground/Code/ID12


Using sparkfun breakout board
[1] GND (Ground)
[2] /RST (Reset Reader) Connect to +5vDC     
[3] ANT (NC)  
[4] ANT (NC)      
[5] CP  (NC) (Card Present)     
[6] NC
[7] FS (Format select) (ground this for ASCII)
[8] D1 (NC)
[9] D0 (TTL Serial) to arduino RX             
[10] Buzzer/LED (Card read indicator) (Connect to transistor + buzzer/led to indicate card was read)		<-- optional
[11] 5v+ ( +5vDC power) 

On Arduino....
[3] (Digital OUT) to Blue LED+
[4] (Digital OUT) to Red LED+
[5] (Digital OUT) to Green LED+
[6] (Digital OUT) to lock relay+ 
[RX0] (Serial IN) to [9] D0 TTL serial out on ID-20


*/

#include <Servo.h>

#define RFIDResetPin	2

#define buttonPin			3
// #define buzzerPin			7
#define servoPin			9
#define redLedPin			12
#define greenLedPin		13
#define blueLedPin		11

#define servoOpen			120
#define servoClose		30

Servo myservo;

boolean match = false;

void setup() {
	Serial.begin(9600);		// connect to the serial port
	
	pinMode(buttonPin, INPUT);

	pinMode(RFIDResetPin, OUTPUT);
	digitalWrite(RFIDResetPin, HIGH);

	// pinMode(buzzerPin, OUTPUT);
	pinMode(blueLedPin, OUTPUT);
	pinMode(greenLedPin, OUTPUT);
	pinMode(redLedPin, OUTPUT);
	
	myservo.attach(servoPin);
	myservo.write(servoClose);
}

void loop ()
{
	byte i = 0;
	byte val = 0;
	byte code[6];
	byte checksum = 0;
	byte bytesread = 0;
	byte tempbyte = 0;
	
	/*
	If the button is pushed we openes the door
	*/
	if(digitalRead(buttonPin))
	{
		openDoor();
	}
	else
	{
		if(Serial.available() > 0)
		{
			if((val = Serial.read()) == 2)
			{                  // check for header 
				bytesread = 0; 
				while (bytesread < 12)
				{                        				// read 10 digit code + 2 digit checksum
					if( Serial.available() > 0)
					{ 
						val = Serial.read();
						if((val == 0x0D)||(val == 0x0A)||(val == 0x03)||(val == 0x02)) { // if header or stop bytes before the 10 digit reading 
							break;										// stop reading
						}

						// Do Ascii/Hex conversion:
						if ((val >= '0') && (val <= '9')) {
							val = val - '0';
							} else if ((val >= 'A') && (val <= 'F')) {
								val = 10 + val - 'A';
							}

							// Every two hex-digits, add byte to code:
							if (bytesread & 1 == 1) {
							// make some space for this hex-digit by
							// shifting the previous hex-digit with 4 bits to the left:
								code[bytesread >> 1] = (val | (tempbyte << 4));

								if (bytesread >> 1 != 5)
								{																				// If we're at the checksum byte,
								checksum ^= code[bytesread >> 1];				// Calculate the checksum... (XOR)
							};
						} else {
							tempbyte = val;														// Store the first hex digit first...
						};

						bytesread++;																// ready to read next digit
					} 
				} 

				// Output to Serial:

				if (bytesread == 12) {													// if 12 digit read is complete
					Serial.print("5-byte code: ");

					for (i=0; i<5; i++) {
						if (code[i] < 16) Serial.print("0");
						Serial.print(code[i], HEX);
						Serial.print(" ");
					}

					Serial.println();

					Serial.print("Checksum: ");
					Serial.print(code[5], HEX);
					Serial.println(code[5] == checksum ? " <- passed." : " <- error.");
					Serial.println();
					
					/*
					Check if the user has access and the checksum is correct
					*/
					if(accessCheck(code) == true && code[5] == checksum) {
						Serial.println("Door unlocked!");
						openDoor();
					} else {
						Serial.println("Access denied!");
						accessDenied();
					}
				}
				bytesread = 0;
			}
		}
	}
}

boolean accessCheck(byte test[]) 
{
	// Number of cards
	byte rfidTags = 4;
	
	byte tags[30] = {
		'0','0','0','0','0','0','0','0','0','0',			// Card 1
		'0','0','0','0','0','0','0','0','0','0',			// Card 2
		'0','0','0','0','0','0','0','0','0','0',			// Card 3
		'0','0','0','0','0','0','0','0','0','0'				// Card 4 
	};
	
	
	for(int numCards=0; numCards<rfidTags; numCards++)
	{
		byte bytesread = 0;
		byte i = 0;
		byte val[10];
		
		for(byte q=0; q<10; q++)
		{
			val[q] = tags[numCards*10+q];
		}
		
		byte master[6];
		byte checksum = 0;
		byte tempbyte = 0;
		bytesread = 0; 

		for (i=0; i<10; i++)			// First we need to convert the array above into a 5 HEX BYTE array
		{
			if ((val[i]>='0') && (val[i]<='9'))		// Convert one char to HEX
			{
				val[i] = val[i] - '0';
			} 
			else if ((val[i]>='A') && (val[i]<='F'))
			{
				val[i] = 10 + val[i] - 'A';
			}

			if (bytesread & 1 == 1) // Every two hex-digits, add byte to code:
			{
			// make some space for this hex-digit by
			// shifting the previous hex-digit with 4 bits to the left:
				master[bytesread >> 1] = (val[i] | (tempbyte << 4));

				if (bytesread >> 1 != 5)							// If we're at the checksum byte,
				{
					checksum ^= master[bytesread >> 1];	// Calculate the checksum... (XOR)
				};
			} 
			else 
			{
				tempbyte = val[i];										// Store the first hex digit first...
			};
			bytesread++;         
		}

		if ( checkTwo(test, master))							// Check to see if the master = the test ID
			return true;
	}
	return false;
}

// Check two arrays of bytes to see if they are exact matches
boolean checkTwo ( byte a[], byte b[] )
{
	if (a[0] != NULL)								// Make sure there is something in the array first
		match = true;									// Assume they match at first

	for (int k = 0;  k<5; k++)			// Loop 5 times
	{
		/*
		Serial.print("[");
		Serial.print(k);
		Serial.print("] ReadCard [");
		Serial.print(a[k], HEX);
		Serial.print("] StoredCard [");
		Serial.print(b[k], HEX);
		Serial.print("] \n");
		*/
		if (a[k] != b[k])							// IF a != b then set match = false, one fails, all fail
		{
			match = false;
		}
	}
	if (match)											// Check to see if if match is still true
	{
	//Serial.print("Strings Match! \n");  
		return true;                  // Return true
	}
	else {
	//Serial.print("Strings do not match \n"); 
		return false;                 // Return false
	}
}



/*
Open the door.

- Open servo
- Green LED blinking

If the button is pushed after 4000ms the keepDoorOpen function is called
*/
void openDoor()
{
	myservo.write(servoOpen);				// Move servo to open position
	
	// digitalWrite(buzzerPin, HIGH);
	digitalWrite(greenLedPin, HIGH);
	delay(4000);	// The time the door needs to be open
	digitalWrite(greenLedPin, LOW);
	// digitalWrite(buzzerPin, LOW);
	
	if(digitalRead(buttonPin))
	{
		keepDoorOpen(); // When the button is pushed the keepDoorOpen function is activated
		openDoor();	// Run this openDoor function again when finished
	}
	
	myservo.write(servoClose);	// Move servo to lock position
}

/*
Keeping the door open until you push the button again.

Stays open for at least 10 * 200ms before you can push the button to lock it

## TODO ##
rewrite the buttonState counter. Do not need to count to 20, just check if the
buttonState==LOW and then HIGH. Then we do not need the 20*200ms delay
*/
void keepDoorOpen()
{
	Serial.println("Keeping the door open.");
	
	int buttonState = 1;
	while(buttonState>0)
	{
		digitalWrite(greenLedPin, HIGH);
		delay(100);
		digitalWrite(greenLedPin, LOW);
		delay(100);
		if(buttonState<=10) buttonState++;
		if(digitalRead(buttonPin)==HIGH && buttonState>=10) break;
	}
	
	/*
	Flashes the red and green LED to indicate that this mode is about to quit
	*/
	for(int i=0; i<4; i++)
	{
		digitalWrite(redLedPin, HIGH);
		delay(100);
		digitalWrite(redLedPin, LOW);
		digitalWrite(greenLedPin, HIGH);
		delay(100);
		digitalWrite(greenLedPin, LOW);
	}
}

/*
Access denied!
Flashes the red LED
*/
void accessDenied()
{
	for(int i=0; i<5; i++) {
		digitalWrite(redLedPin, HIGH);
		delay(100);
		digitalWrite(redLedPin, LOW);
		delay(100);
	}
}