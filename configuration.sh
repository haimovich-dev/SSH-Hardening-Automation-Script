
sudo rm /etc/ssh/moduli # Moduli file removal, DH KEX are not used

# sudo ssh-keygen -M generate -O bits=4096 /etc/ssh/moduli.candidates

# sudo ssh-keygen -M screen -f /etc/ssh/moduli.candidates /etc/ssh/moduli